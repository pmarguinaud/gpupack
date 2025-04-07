#!/usr/bin/perl -w

use strict;

use FileHandle;
use Data::Dumper;
use Getopt::Long;
use File::stat;
use File::Basename;
use FindBin qw ($Bin);
use lib "$Bin/../lib";

use Common;

use Fxtran;
use Dimension;

my $F90 = shift;

my $d = &Fxtran::parse (location => $F90, fopts => [qw (-construct-tag -no-include -no-cpp -line-length 500)]);

&Dimension::attachArraySpecToEntity ($d);

print $d->textContent;
