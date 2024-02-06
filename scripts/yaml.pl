#!/usr/bin/perl -w

use YAML;
use Data::Dumper;
use FileHandle;
use strict;

my ($yaml, $path) = @ARGV;

my $x = &YAML::LoadFile ($yaml);

my @path = split (m,/,o, $path);

for my $path (@path)
  {
    if (ref ($x) eq 'HASH')
      {
        $x = $x->{$path};
      }
    elsif (ref ($x) eq 'ARRAY')
      {
        $x = $x->[$path];
      }
  }

print $x;
