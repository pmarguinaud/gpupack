#!/usr/bin/perl  

use strict;
use File::Find;
use FileHandle;

=pod

find $MKTOP/$GMKLOCAL/$prj -type f -name "*" -print | \
xargs grep -h ".*include .*\.intfb\.h" | \
sed -e "s/\.intfb\.h.*/\.intfb\.h/" -e "s/.* [\"\']//" -e "s/ //g" | \
grep "^[1234567890A-Za-z]" | sort -u > $MyTmp/included_intfbfiles

=cut

my %inc;

sub wanted
{
  my $f = $File::Find::name;
  return unless ((-f $f) && ($f =~ m/\.(?:F(?:90)?|h)$/io));
  my $fh = 'FileHandle'->new ("<$f");
  my @inc = grep { m/\s*#include\s*"(.*?\.intfb\.h)"/o; $_ = $1 } <$fh>;
  @inc{@inc} = @inc;
}

&find ({wanted => \&wanted, no_chdir => 1}, $ARGV[0]);

my @inc = sort keys (%inc);

local $" = "\n";

@inc &&
print "@inc\n";





