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

my @contains = &F ('.//contains-stmt', $d);

for my $contains (@contains)
  {
    my $p = $contains;
    my @p;
    while ($p->nextSibling)
      {
        push @p, $p;
        $p = $p->nextSibling;
      }
    for (@p)
      {
        $_->unbindNode ();
      }
  }


'FileHandle'->new (">$F90")->print ($d->textContent);

unlink ("$F90.xml");
