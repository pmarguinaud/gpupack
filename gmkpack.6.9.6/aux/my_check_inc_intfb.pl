#!/usr/bin/perl  

use strict;
use warnings;
use FindBin qw ($Bin);
use lib $Bin;

use Fortran90_stuff;

{
  my (@files);
  (@files) = @ARGV;
  &setup_parse();
  for (@files) {
    my (@interface_block);
    my (%prog_info);
    my (%calls,%intfbs);
    my $fail=0;
    chomp;
 # Read in lines from file
    my $fname = $_;
    my @lines = &readfile($fname);
    my @statements=(); 
    &expcont(\@lines,\@statements);
    &study(\@statements,\%prog_info);
    &getcalls(\@statements,\%calls,\%intfbs);
    foreach my $intfb (keys (%intfbs)) {
      print "INCLUDE $intfb\n";
    }
    foreach my $call (keys (%calls)) {
      print "CALL $call\n";
    }
  }
}
