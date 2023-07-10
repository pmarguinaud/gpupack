#!/usr/bin/perl  -w

use strict;
use File::Find;
use File::Spec;
use FileHandle;
use Data::Dumper;
use Cwd;

=head1 NAME

mkdh2f.pl

=head1 DESCRIPTION

mkdh2f.pl generates the mapping between dr_hook tags (the string passed as argument to dr_hook),
and source file names. The result is stored in dh2f.pl.

mkdh2f.pl must be run from a pack main directory.

=head1 AUTHOR

Philippe.Marguinaud@meteo.fr

=cut


sub wanted
{
  my $f2b = shift;
  my $b = shift;

  my $f = 'File::Spec'->canonpath ($File::Find::name);
  return unless (m/\.f(?:90)?$/io);

  $f2b->{$f} = $b;

}


my %f2b;
my %x;

my $gmkview = do { my $fh = 'FileHandle'->new ("<.gmkview"); local $/ = undef; <$fh> };
chomp ($gmkview);

my @gmkview = reverse (split (m/\n/o, $gmkview));
chomp for (@gmkview);

my @dir = map ({ "src/$_" } @gmkview);


my $cwd = &cwd ();
for my $dir (@dir)
  {
    chdir ($dir);
    find ({wanted => sub { &wanted (\%f2b, $dir) }, no_chdir => 1}, '.');
    chdir ($cwd);
  }

while (my ($f, $b) = each (%f2b))
  {
    my $code = do { local $/ = undef; my $fh = 'FileHandle'->new ("<$b/$f"); <$fh> };
    my @ht = ($code =~ m/dr_hook\(['"]([^'"]+)['"]/gomsi);
    
    for my $ht (@ht)
      {
        $x{$ht} = $f;
      }
  }

'FileHandle'->new ('>dh2f.pl')->print (Dumper (\%x));


