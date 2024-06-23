#!/usr/bin/perl -w

use strict;
use FileHandle;
use Data::Dumper;
use File::Find;
use File::Spec;

sub slurp
{
  my $f = shift;
  return do { my $fh = 'FileHandle'->new ("<$f"); local $/ = undef; <$fh> };
}

my ($pack) = @ARGV;
$pack ||= '.';

die unless (-f "$pack/.gmkview");

$pack = 'File::Spec'->rel2abs ($pack);

chdir ($pack);

chomp for (my @view = do { my $fh = 'FileHandle'->new ('<.gmkview'); <$fh> });

my %parallel;

for my $view (@view)
  {
    &find
    (
      {
        wanted => sub 
        { 
          my $f = $File::Find::name; 
          return unless ((-f $f) && (($f =~ m/_parallel\d*\.F90/o) || ($f =~ m,/(?:stepo|exchange_ms_modnew|trmtosnew|trstomnew)\.F90$,o))); 
          my $g = 'File::Spec'->abs2rel ($f, "$pack/src/$view");
          $parallel{$g} ||= $f;
        },
        no_chdir => 1,
      }, "$pack/src/$view/"
    );
  }

my %section2method;

for my $f (keys (%parallel))
  {
    my $code = &slurp ($parallel{$f});
    my @method = ($code =~ m/LPARALLELMETHOD\s*\('([^']+)'\s*,\s*'([^']+)'\s*\)/goms);

    while (my ($method, $section) = splice (@method, 0, 2))
      {
        for ($method, $section)
          {
            s/\&\s*\&//goms;
            $_ = uc ($_);
          }
        $section2method{$section}{$method} = 1;
      }

  }

for my $METHOD (qw (OPENMP OPENMPSINGLECOLUMN OPENACCSINGLECOLUMN))
  {
    my $fh = 'FileHandle'->new (">$pack/lparallelmethod.txt.$METHOD");
    for my $section (sort keys (%section2method))
      {
        my @method = ($METHOD);

        push @method, ('OPENMPMETHOD')             if ($METHOD =~ m/^OPENMP/o);
        push @method, ('OPENACCMETHOD', 'OPENACC') if ($METHOD =~ m/^OPENACC/o);
          
        push @method, ('OPENMP', 'UPDATEVIEW');

        for my $method (@method)
          {
            if ($section2method{$section}{$method})
              {
                $fh->printf ("%-40s %s\n", $method, $section);
                last;
              }
          }
      }
    $fh->close ();
  }
    
    
