#!/usr/bin/perl  

use strict;
use File::Path;
use FileHandle;
use File::Basename;
use Data::Dumper;
use FindBin qw ($Bin);
use lib $Bin;

########################################################################
#
#    Script splitpack
#    --------------
#
#    Purpose : In the framework of a pack : to split a compilation list
#    -------   of elements into distributable lists
#              Break search when the first precedure is reached and there
#              are already selected elements, in order to limit the time 
#              spent for splitting.
#
#    Usage : splitpack $1 $2
#    -----
#               $1 : (input) list of dependent files
#               $2 : (output) tar file of sorted lists
#
#    Environment variables :
#    ---------------------
#            ICS_ECHO : Verboose level (0 or 1 or 2)
#            GMKWRKDIR   : main working directory
#
########################################################################
#
#
#
#

my $debug = 0;

# environment variables

my $GMKWRKDIR   = &uev ('GMKWRKDIR');
my $GMAKDIR     = &uev ('GMAKDIR');
my $MKTOP       = &uev ('MKTOP');

# helper functions

sub uev
{
  my $k = shift;
  exists ($ENV{$k}) && return $ENV{$k};
  die ("Environment variable $k is not set\n");
}

sub lslurp
{
  my $f = shift;
  my @x = do { my $fh = 'FileHandle'->new ("<$f"); $fh or die ("Cannot open <$f"); <$fh> };
  chomp for (@x);
  return @x;
}

# sort source files by size (biggest first)
sub sort_size_rr
{
  my @src = grep { !m/\.h$/o } @_;
  my @inc = grep {  m/\.h$/o } @_;

  my @src1 = map { (my $f = $_) =~ s,\@,/,o; "$MKTOP/$f" } @src;
  my @size = map { -s $_ } @src1;
  my @indx = sort { $size[$b] <=> $size[$a] } (0 .. $#size); # sort indices

  @src = @src[@indx];

  return (\@src, \@inc);
}

# program arguments

my ($comp_list_deps, $ics_lists_tar) = @ARGV;


print "Sort all projects together ...\n";

my $MyTmp = "$GMKWRKDIR/splitpack";
mkpath ($MyTmp);
chdir ($MyTmp);


# Load full GMAK output once

our (%GMKFPROP, %GMKNAME);
do ("$GMAKDIR/view");

if (my $c = $@)
  {
    die ("Cannot load `$GMAKDIR/view' : $c\n");
  }

#
rmtree (<ics_list.*>) if (<ics_list.*>);

#

my @elements = &lslurp ($comp_list_deps);

my %F2elements;

my @F = map 
          { 
	    (my $e = $_) =~ m/^([^@]+)@(.*\.([^\.]+))$/o; 
	    my $F = $2; 
	    $F2elements{$F} = $e; 
	    $F 
          } @elements;

my %OK2H = map 
             { 
               my $h = $_; 
	       (my $ok = basename ($h)) =~ s/\.h$/\.ok/o; 
	       ($ok, $h) 
             } 
	   grep { m/\.h$/o } keys (%GMKFPROP);

my %use;


my ($level) = (-1);

sub use
{
  $level++;

  my ($F) = @_;

  $debug && print ('  ' x $level, "-- $F\n");


  if ((grep { $F eq $_ } @_) > 1)
    {
      die Dumper (\@_);
    }

  unless ($use{$F})
    {
      $debug && print ('  ' x $level, "deps=@{$GMKFPROP{$F}{deps}}\n");
      %{ $use{$F} } = map 
                        { 
                          my $dep = $_;  
			  my %u;
			  if ($dep =~ s/\.mod$//o)
			    {
			      $debug && print ('  ' x $level, "dep=$dep (GMKNAME=", $GMKNAME{$dep} || '???', ")\n");
                              $dep = $GMKNAME{$dep};
			      if ($dep)
			        {
                                  # case of a subroutine using a module 
			          # defined in the same file :
			          # $ cat ab.f90
			          # module a
			          # end module
			          # subroutine b
			          # use a
			          # end subroutine
			          #
                                  if ($dep ne $F)
			            {
			              %u = ($dep, 1);
				    }
                                }
                            }
			  elsif ($dep =~ m/\.ok$/o)
			    {
			      $debug && print ('  ' x $level, "dep=$dep (OK2H= ", $OK2H{$dep} || '???', ")\n");
                              $dep = $OK2H{$dep};
			      %u = $dep ? %{ $use{$dep} || &use ($dep, @_) }: ();
                            }
			  else
			    {
# do not die : this may be just an included passive header ... or even a mistyping
#                              die ("Unknown dependency $dep\n");
                            }
                          %u
			} 
		      @{$GMKFPROP{$F}{deps} || []};
    }
  $level--;

  $debug && print ("\n");

  return $use{$F};
}

local $SIG{__WARN__} = sub { die "@_\n" };
#


for my $F (@F)
  {
    &use ($F);
  }

'FileHandle'->new ('>use.pl')->print (Dumper(\%use));

my @inc;

my ($i) = (2);
while (%use)
  {

    # select files without any dependencies
    my @f = grep 
              { 
		my $F = $_; 
		! keys (%{ $use{$F} })
	      } 
	    keys (%use);

    # remove selected files from the list of dependencies of other units
    for my $k (keys (%use))
      {
        my $v = $use{$k};
        delete @{$v}{@f};
      }

    # remove selected files
    delete @use{@f};
    
    # dump file list (rename with branch prefix)
    
    my ($src, $inc) = &sort_size_rr (map { $F2elements{$_} } @f);
    my $list = join ("\n", @$src, '');

    push @inc, @$inc;
    
    'FileHandle'->new (">ics_list.$i")->print ($list);
    
    $debug &&
    'FileHandle'->new (">use.$i.pl")->print (Dumper(\%use));
    
    $i++;

  }

'FileHandle'->new (">ics_list.1")->print (join ("\n", @inc, ''));

system ('tar', cf => $ics_lists_tar, <ics_list.*>);
chdir ($GMKWRKDIR);

rmtree ('splitpack');



