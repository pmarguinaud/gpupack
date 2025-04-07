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
use Construct;
use Canonic;

my $F90 = shift;
my %c = @ARGV;

my $d = &Fxtran::parse (location => $F90, fopts => [qw (-canonic -construct-tag -no-include -line-length 800)]);

&Canonic::makeCanonic ($d);

for (values (%c))
  {
    $_ = &e ($_);
  }

&Construct::apply ($d, %c);

print &Canonic::indent ($d);


