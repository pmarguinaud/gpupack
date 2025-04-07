#!/usr/bin/perl -w

use strict;
use local::lib;
use FindBin qw ($Bin);
use lib "$Bin/../lib";

use Data::Dumper;
use FileHandle;

use Fxtran;
use File::Find;
use File::Basename;
use File::Copy;

my $F90 = shift;

my $d = &Fxtran::parse (location => $F90, fopts => [qw (-line-length 800 -no-include -no-cpp -construct-tag)]);

my @pu = &F ('.//program-unit[count(ancestor::program-unit)=1]', $d);


my @keep = qw (subroutine-stmt end-subroutine-stmt function-stmt end-function-stmt use-stmt T-decl-stmt);
my %keep = map { ($_, 1) } @keep;

for my $pu (@pu)
  {
    my @node = &F ('./*', $pu);
    for my $node (@node)
      {
        next if ($keep{$node->nodeName});
        $node->unbindNode ();
      }
  }

'FileHandle'->new (">$F90")->print ($d->textContent);

unlink ("$F90.xml");

