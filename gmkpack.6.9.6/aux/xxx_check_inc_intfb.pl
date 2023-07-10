#!/usr/bin/perl  

use FindBin qw ($Bin);
use lib $Bin;

sub unic
{
  my $ref = shift();
  my %tmp = ();
  @$ref = grep { $tmp{$_}++ == 0 } @$ref;
}

my $file    = shift();
my $content = undef;
my $vob     = $ENV{GMK_VOB};
my $mktop   = "$ENV{TARGET_PACK}/src";
my @gmkview = reverse split /\s+/, $ENV{GMKVIEW};

# read input file
unless ( open F, $file ) {
  eval { close F };
  print STDERR "Can't open file $file for reading\n";
  exit(1);
}

{ local($/) = undef; $content = <F> }
close F;

$content = lc($content);

# remove comments & misc cleanings
$content =~ s/^\s*\!.*$//mg;
$content =~ s/\!.*$//mg;
$content =~ s/\t+/ /sg;
$content =~ s/\&\n\s*[\&]?/ /sg;

# get name of routine
$content =~ s/\brecursive\b\s/ /sg; #!!!
( undef, my $name ) = ( $content =~ /^\s*(program|subroutine|function)\s+(\w+)/m );

# mandatory interfaces
( my @intfb ) = ( $content =~ /^#include[ ]*['"]([\w\-]+)\.intfb\.h['"]/mg );
@intfb = grep { $_ ne 'abor1' } @intfb; # sans commentaire...
print "INCLUDE $_\n" for ( sort @intfb );

$content =~ s/^/ /mg;

# fetch calls
( my @calls ) = ( $content =~ /\s+call\s+(\w+)/sg );
unic(\@calls);

# fetch what could be functions...
( my @func ) = ( $content =~ /\b(\w+)\b\s*\(/sg );

my @list = ();

# read interfaces list
foreach my $branch ( @gmkview ) {
  my $intfbdir = "$mktop/$branch/.intfb/$vob";
  opendir DIR, $intfbdir;
  push(@list,readdir(DIR));
  close DIR;
}

unic(\@list);

# get "interfaced" calls & functions
my %flag = ();
foreach my $call ( @calls, @func ) {
  next if defined($flag{$call});
  next if ( $call eq $name );
  $flag{$call} = 1;
  if ( grep /^$call\.intfb\.h$/i, @list ) {
    print "CALL $call\n";
    next;
  }
}

exit(0);

