#!/usr/bin/perl  -w

use strict;
use FileHandle;
use Data::Dumper;

=head1 NAME

mknamhook.pl

=head1 DESCRIPTION

mknamhook.pl creates a namelist for the dr_hook_all package.
Your pack must have been compiled with the C<export GMK_DR_HOOK_ALL=1> option.

Here is how to use mknamhook.pl:

 $ mknamhook.pl drhook.1 3 namelist.hook_all

The command above takes as input a dr_hook profile (drhook.1), and will generate
a namelist (namelist.hook_all), where files whose subroutines yielded less than
3 ms (both CPU and elapsed time) will be excluded from dr_hook instrumentation.

Some files (those which contain several subroutines) may show conflicts: one subroutine
will yield more than 3 ms, which another will have elapsed less than 3 ms.
The names of these files is printed by mknamhook.pl.

Note that mknamhook.pl requires that mkdh2f.pl have been run. mknamhook.pl must 
be run from the pack main directory.

=head1 AUTHOR

Philippe.Marguinaud@meteo.fr

=cut


die ("Usage: $0 drhook.1 ms namhook\n")
  unless (@ARGV == 3);
  

my ($drhook, $threshold, $namhook) = @ARGV;

my $fh = 'FileHandle'->new ("<$drhook");

# skip header

for (1 .. 13)
  {
    my $line = <$fh>;
  }


my $dh2f = do ('dh2f.pl');
if ($@)
  {
    die ("dh2f.pl is required by mknamhook.pl; run mkdh2f.pl first");
  }


my (%p, %m);

while (my $line = <$fh>)
  {
    chomp ($line);
    $line =~ s/(?:^\s*|\s*$)//go;
    my @x = split (m/\s+/o, $line);
    my ($self, $totl, $rtne) = @x[$#x-2 .. $#x-0];

    $rtne =~ s/\@\d+$//o;


    if (($totl < $threshold) && ($self < $threshold))
      {
        $m{$dh2f->{$rtne}}++
          if ($dh2f->{$rtne});
      }
    else
      {
        $p{$dh2f->{$rtne}}++
          if ($dh2f->{$rtne});
      }

  }


my $fhn = 'FileHandle'->new (">$namhook");

$fhn->print ("&namhook__all\n");
$fhn->print ("lhook = .true.\n");

my @r;

my $i = 1;
for my $f (keys (%m))
  {
    if ($p{$f})
      {
        push @r, $f;
      }
    else
      {
        $fhn->print ("files_hook($i) = '-$f'\n");
        $i++;
      }
  }

@r &&
  print (join ("\n", "Could not remove :", @r, ''));

$fhn->print ("/\n");
$fhn->close ();


