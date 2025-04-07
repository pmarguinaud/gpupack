#!/usr/bin/perl -w

#
# Copyright 2022 Meteo-France
# All rights reserved
# philippe.marguinaud@meteo.fr
#

#
use strict;
use local::lib;
use FindBin qw ($Bin);
use lib "$Bin/../lib";

use Getopt::Long;
use Data::Dumper;
use FileHandle;
use File::Basename;
use File::stat;
use List::MoreUtils qw (uniq);

use Fxtran;
use Decl;
use Pointer::Object;
use Pointer::SymbolTable;
use Pointer::Parallel;
use Loop;
use Call;
use Associate;
use Subroutine;
use Finder::Pack;
use Include;
use DIR;
use Bt;
use Canonic;
use Directive;
use Inline;

use Cycle49;

sub updateFile
{
  my ($F90, $code) = @_;

  my $c = do { local $/ = undef; my $fh = 'FileHandle'->new ("<$F90"); $fh ? <$fh> : undef };
  
  if ((! defined ($c)) || ($c ne $code))
    {
      unlink ($F90);
      'FileHandle'->new (">$F90")->print ($code);
    }
}

my $suffix = '_sync';

sub processSingleRoutine
{
  my ($d, $NAME, $find, $types, %opts) = @_;

  for my $jlon  (@{ $opts{jlon} })
    {
      my @expr = &F ('.//named-E[string(N)="?"]/N/n/text()', $jlon, $d);
      for (@expr) 
        {
          $_->setData ('JLON');
        }
    }
  
  for my $unseen (&F ('.//unseen', $d))
    {
      $d->unbindNode ();
    }
  
  &Subroutine::rename ($d, sub { return $_[0] . uc ($suffix) });
  
  # Prepare the code
  
  &Associate::resolveAssociates ($d);
  
  if ($opts{'inline-contains'})
    {
      &Construct::changeIfStatementsInIfConstructs ($d);
      &Inline::inlineContainedSubroutines ($d, skipDimensionCheck => 1);
    }
  
  if ($opts{cycle} == 49)
    {
      &Cycle49::simplify ($d);
    }
  
  
  if ($opts{addYDCPG_OPTS})
    {
      &addYDCPG_OPTS ($d);
    }
  
  &Decl::forceSingleDecl ($d);
  
  &Directive::parseDirectives ($d, name => 'ACDC');
  
  # Add modules
  
  my @use = qw (FIELD_MODULE FIELD_FACTORY_MODULE FIELD_ACCESS_MODULE);
  
  &Decl::use ($d, map { "USE $_" } @use);
  
  # Add local variables
  
  my $t = &Pointer::SymbolTable::getSymbolTable 
    ($d, skip => $opts{skip}, nproma => $opts{nproma}, 
     'types-fieldapi-dir' => $opts{'types-fieldapi-dir'},
     'types-constant-dir' => $opts{'types-constant-dir'},
     'types-fieldapi-non-blocked' => $opts{'types-fieldapi-non-blocked'});
    
  
  # Remove SKIP sections
  
  for (&F ('.//skip-section', $d))
    {
      $_->unbindNode ();
    }
  
  # Transform NPROMA fields into a pair of (FIELD API object, Fortran pointer)
  
  &Pointer::Parallel::fieldifySync
    (
       'program-unit' => $d, 
       'symbol-table' => $t, 
       'find'         => $find,
       'types'        => $types,
    );

  return;

  # Process ABORT sections

  my @abort = &F ('.//abort-section', $d);

  for my $abort (@abort)
    {
      $_->unbindNode ()
        for (&F ('./*', $abort));
      $abort->appendChild ($_)
        for (&s ('CALL ABOR1 ("ERROR: WRONG SETTINGS")'), &t ("\n"));
    }
  
  # Process PARALLEL sections
  
  my @call = &F ('.//call-stmt[not(string(procedure-designator)="DR_HOOK")]'  # Skip DR_HOOK calls
              . '[not(string(procedure-designator)="ABOR1")]'                 # Skip ABOR1 calls
              . '[not(string(procedure-designator)="ABORT")]'                 # Skip ABORT calls
              . '[not(string(procedure-designator)="GETENV")]'                # Skip ABORT calls
              . '[not(procedure-designator/named-E/R-LT)]'                    # Skip objects calling methods
              . '[not(ancestor::serial-section)]', $d);                       # Skip calls in serial sections
  
  my %seen;
  
  for my $call (@call)
    {
      if (&Pointer::Parallel::callParallelRoutine ($call, $t, $types))
        {
          # Add include for the parallel CALL
          my ($name) = &F ('./procedure-designator/named-E/N/n/text()', $call);
          unless ($seen{$name->textContent}++)
            {
              my ($include) = &F ('.//include[./filename[string(.)="?" or string(.)="?"]', lc ($name) . '.intfb.h', lc ($name) . '.h', $d);
              $include or die $call->textContent;
              $include->parentNode->insertAfter (&n ('<include>#include "<filename>' . lc ($name) . '_parallel.intfb.h</filename>"</include>'), $include);
              $include->parentNode->insertAfter (&t ("\n"), $include);
            }
          $name->setData ($name->data . uc ($suffix));
        }
    }
  
}


my %opts = ('types-fieldapi-dir' => 'types-fieldapi', skip => 'PGFL,PGFLT1,PGMVT1,PGPSDT2D', 
             nproma => 'YDCPG_OPTS%KLON,YDGEOMETRY%YRDIM%NPROMA', 'types-constant-dir' => 'types-constant',
             'post-parallel' => 'nullify', cycle => '49', 'jlon', 'JLON', 
             'types-fieldapi-non-blocked' => 'CPG_SL1F_TYPE,CPG_SL_MASK_TYPE');
my @opts_f = qw (help only-if-newer version stdout addYDCPG_OPTS redim-arguments stack84 use-acpy inline-contains);
my @opts_s = qw (skip nproma types-fieldapi-dir types-constant-dir post-parallel dir cycle jlon types-fieldapi-non-blocked);

&GetOptions
(
  (map { ($_, \$opts{$_}) } @opts_f),
  (map { ("$_=s", \$opts{$_}) } @opts_s),
);

for my $opt (qw (nproma jlon types-fieldapi-non-blocked))
  {
    $opts{$opt} = [split (m/,/o, $opts{$opt})];
  }

if ($opts{help})
  {
    print
     "Usage: " . &basename ($0) . "\n" .
      join ('', map { "  --$_\n" } @opts_f) .
      join ('', map { "  --$_=...\n" } @opts_f) .
     "\n";
    exit (0);
  }

$opts{skip} = [split (m/,/o, $opts{skip} || '')];

my $F90 = shift;
(my $F90out = $F90) =~ s/.F90$/$suffix.F90/o;

unless ($opts{dir})
  {
    $opts{dir} = &dirname ($F90out);
  }

$F90out = 'File::Spec'->catpath ('', $opts{dir}, &basename ($F90out));

if ($opts{'only-if-newer'})
  {
    my $st = stat ($F90);
    my $stout = stat ($F90out);
    if ($st && $stout)
      {
        exit (0) unless ($st->mtime > $stout->mtime);
      }
  }

my $NAME = uc (&basename ($F90out, qw (.F90)));

my $find = 'Finder::Pack'->new ();

my $types = &Storable::retrieve ("$opts{'types-fieldapi-dir'}/decls.dat");

my $d = &Fxtran::parse (location => $F90, fopts => [qw (-line-length 800 -no-include -no-cpp -construct-tag -directive ACDC -canonic)]);

for my $pu (&F ('./object/file/program-unit', $d))
  {
    &processSingleRoutine ($pu, $NAME, $find, $types, %opts);
  }

if ($opts{version})
  {
    my $version = &Fxtran::getVersion ();
    my ($file) = &F ('./object/file', $d);
    $file->appendChild (&n ("<C>! $version</C>"));
    $file->appendChild (&t ("\n"));
  }

if ($opts{stdout})
  {
    print &Canonic::indent ($d);
  }
else
  {
print &Canonic::indent ($d);
    &updateFile ($F90out, &Canonic::indent ($d));
  }



