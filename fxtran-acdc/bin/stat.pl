#!/usr/bin/perl -w

use strict;
use local::lib;
use FindBin qw ($Bin);
use lib "$Bin/../lib";

use Data::Dumper;
use FileHandle;

use Fxtran;

my $F90 = shift;

my $d = &Fxtran::parse (location => $F90, fopts => [qw (-line-length 800 -no-include -no-cpp -construct-tag -canonic)]);

my @expr = &F ('.//named-E', $d);

my %expr;

for my $expr (@expr)
  {
    my $ar;

    ($ar) = &F ('./R-LT/parens-R', $expr);
    $ar && $ar->unbindNode ();

    ($ar) = &F ('./R-LT/array-R', $expr);
    $ar && $ar->unbindNode ();

    $expr{$expr->textContent}++;
  }

@expr = sort { $expr{$a} <=> $expr{$b} } keys (%expr);

for my $expr (@expr)
  {
    next  unless ($expr =~ m/%/o);
#   printf ("%-40s %8d\n", $expr, $expr{$expr});
  }


for my $expr (@expr)
  {
    next  unless ($expr =~ m/%/o);
    (my $x = $expr) =~ s/%/_/go;
    printf ("%-40s => %s,\n", "'" . $expr . "'", "'" . $x . "'");
  }








