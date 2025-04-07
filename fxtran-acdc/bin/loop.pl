#!/usr/bin/perl -w

use strict;

use Data::Dumper;
use Getopt::Long;
use File::Path;
use File::Spec;
use FindBin qw ($Bin);
use lib "$Bin/../lib";

use Common;
use Fxtran;

my $F90 = shift;

my $d = &Fxtran::parse (location => $F90, fopts => [qw (-canonic -construct-tag -no-include -line-length 800)]);

my @do = &F ('.//do-construct[not(ancestor::do-construct)]', $d);
my %seen;


for my $do (@do)
  {
    next if ($seen{$do->unique_key}++);

    my @doo;

    for (my $x = $do; $x; $x = $x->nextSibling)
      {
        next if ($x->nodeName eq '#text');
        $seen{$x->unique_key}++;
        last unless ($x->nodeName eq 'do-construct');
        push @doo, $x;
      }
    
    print &Dumper ([map { "\n" . $_->textContent } @doo]);
  }



