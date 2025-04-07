#!/usr/bin/perl -w

use strict;

use FileHandle;
use File::Copy;
use File::Basename;
use File::stat;
use File::Path;
use Getopt::Long;
use Data::Dumper;
use FindBin qw ($Bin);
use lib "$Bin/../lib";

use Common;
use Canonic;
use Fxtran;
use Directive;

my $F90 = shift;

my $d = &Fxtran::parse (location => $F90, fopts => [qw (-construct-tag -no-include -line-length 500 -directive ACDC -canonic)]);
      
&Directive::parseDirectives ($d, name => 'ACDC');

print $d;

