#!/usr/bin/env perl  
#
#
use strict;
use FindBin qw ($Bin);
use lib "$Bin/../../aux";

use File::Find;
use File::Path;
use File::Copy;
use FileHandle;
use File::Basename;
use Data::Dumper;



########################################################################
#
#    Script mkintfb
#    ----------------
#
#    Purpose : In the framework of a pack : to make interface blocks
#    -------
#
#    Usage : mkintfb $1 $2 $3
#    -----
#              $1 : (input) list of files in pack
#              $2 : (input) list of modules in pack
#              $3 : (output) list of interface blocks
#
#    Environment variables :
#    ---------------------
#            GMKROOT        : gmkpack root directory
#            MKMAIN         : directory of local source files
#            MKTOP          : directory of all source files
#            GMKWRKDIR         : main working directory
#            GMKINTFB       : relative auto-generated interfaces blocks directory
#            LIST_EXTENSION : Extension for listings
#            GMKVIEW     : Branches list (from bottom to top)
#            ICS_ECHO       : Verboose level
#            INTFBLIST      : Interface blocks projects list 
#
########################################################################

# Ancillary subroutines

sub lR
{
  my $f = shift;
  my $fh = 'FileHandle'->new ("<$f");
  my @x = <$fh>; 
  chomp for (@x); 
  return @x;
}

sub lW
{
  my $f = shift;
  'FileHandle'->new (">$f")->print (join ("\n", @_, ''));
}

sub comm23
{
  my ($x, $y) = @_;
  my %x = map { ($_, 1) } @$x;
  my %y = map { ($_, 1) } @$y;
  my %xy = (%x, %y);
  my @xy23 = grep { $x{$_} && (!$y{$_}) } keys (%xy);
  return @xy23;
}

sub mtime
{
  my $f = shift;
  return ((stat ($f))[9] || 0);
}

sub cat
{
  my $f = shift;
  my $fh = 'FileHandle'->new ("<$f");
  while (my $line = <$fh>)
    {
      print $line;
    }
}

local $SIG{__WARN__} = sub { die ("@_") };

#


# Read environment variables

my $LOC_INTFBDIR   = $ENV{LOC_INTFBDIR};
my $GMKINTFB       = $ENV{GMKINTFB};
my @INTFBLIST      = split (m/\s+/o, $ENV{INTFBLIST});
my @GMKVIEW        = &lR ("$ENV{TARGET_PACK}/.gmkview");
my $LIST_EXTENSION = $ENV{LIST_EXTENSION};
my $MKTOP          = $ENV{MKTOP};
my $GMKLOCAL       = $ENV{GMKLOCAL};
my $ICS_IFCMODE    = $ENV{ICS_IFCMODE} || '';
my $ICS_ECHO       = $ENV{ICS_ECHO};
my $GMKROOT        = $ENV{GMKROOT};
my $MKMAIN         = $ENV{MKMAIN};
my $GMKWRKDIR      = $ENV{GMKWRKDIR};
my $GMKBUILD       = $ENV{GMKBUILD};

#

# Temporary directory where interface blocks are created :
# ------------------------------------------------------
if (-d $LOC_INTFBDIR)
  {
    rmtree ($_) for (<$LOC_INTFBDIR/*>);
  }
else
  {
    mkpath ($LOC_INTFBDIR);
  }

my ($packlist, $modlist, $intfblist) = @ARGV;

my @packlist = &lR ($packlist);
my @modlist  = &lR ($modlist);


chdir ($MKMAIN);


mkpath ($GMKINTFB);

for my $prj (@INTFBLIST)
  {
    mkpath ("$GMKINTFB/$prj");
  }

if (scalar (@GMKVIEW) > 1)
  {
#   Control that all existing interface blocks rely on an existing F90 procedure :
#   ----------------------------------------------------------------------------
    for my $prj (@INTFBLIST)
      {
        my %f;
	find ({wanted => sub { $f{basename($File::Find::name)}++ }, no_chdir => 1}, $prj);
        for my $intfb (<$GMKINTFB/$prj/*.intfb.h>)
	  {
            my $f = basename ($intfb, qw(.intfb.h)) . '.F90';
            my $fypp = basename ($intfb, qw(.intfb.h)) . '.fypp';
	    $f{$f} or $f{$fypp} or do
	      {
                unlink ($intfb);
		print "remove unsupported interface block $intfb\n";
              };
          }
      }
  }

# Select files to apply explicit interface generator :
# --------------------------------------------------
# First we remove the modules:
# Then we select the projects:
#

my $prj_regex = '^(?:' . join ('|', @INTFBLIST) . ')';
my @all = grep { m/$prj_regex/o }
          grep { m/\.F90$/o } 
	  &comm23 (\@packlist, \@modlist);

# Generate explicit interface blocks + update pack content :
# --------------------------------------------------------




chdir ($GMKBUILD);

for my $file (@all)
  {
    my ($prj) = ($file =~ m,^(\w+)/,o);
    my ($base, $dir) = fileparse ($file);
    my $name    = basename ($base, qw(.F90));
    my $listing = "$MKMAIN/$GMKINTFB/$prj/$name.$LIST_EXTENSION";
    my $intfb   = "$name.intfb.h";

#   Directory where the last existing version of this interface block should be :
    my $INTFBDIR       = "$MKTOP/$GMKLOCAL/$GMKINTFB/$prj";
    my $PRINT_INTFBDIR = "$GMKLOCAL/$GMKINTFB/$prj";

    for my $br (@GMKVIEW)
      {
        if (-f "$MKTOP/$br/$GMKINTFB/$prj/$intfb")
	  {
	    $INTFBDIR = "$MKTOP/$br/$GMKINTFB/$prj";
            last;
          }
      }
    $ENV{INTFBDIR} = $INTFBDIR;

    if ((! -f "$INTFBDIR/$intfb") or
	(&mtime ($file) > &mtime ("$INTFBDIR/$intfb")) 
	or ($INTFBDIR ne $PRINT_INTFBDIR))
      {

#       print Dumper ([$file, "$INTFBDIR/$intfb", -f "$INTFBDIR/$intfb", &mtime ($file), &mtime ("$INTFBDIR/$intfb")]);
        my $c = &make_intfbl ($file, "$LOC_INTFBDIR/report");
	if ($c == 0)
	  {
            if (-f "$LOC_INTFBDIR/$intfb")
	      {
                if ($ICS_ECHO > 1)
		  {
                    print "file=$file dir=$PRINT_INTFBDIR $intfb : ",
		           (-f "$INTFBDIR/$intfb" ? 'updated' : 'created'), "\n";
                  }
#         Interface block to be created/updated, store it at the proper place :
                unlink ($listing);
		move ("$LOC_INTFBDIR/$intfb", "$MKMAIN/$GMKINTFB/$prj/$intfb");
              }
            elsif ($ICS_ECHO > 1)
	      {
                print ("file=$file dir=$PRINT_INTFBDIR $intfb : no-changes\n");
	      }

          }
	else
	  {
            if ($ICS_ECHO > 1)
	      {
                print ("file=$file dir=$PRINT_INTFBDIR $intfb : failed\n");
              }
#       The procedure failed :
            move ("$LOC_INTFBDIR/report", $listing);
	    'FileHandle'->new (">>$LOC_INTFBDIR/errorlog")->print ("$listing\n");
	  }

      }
    elsif ($ICS_ECHO > 1)
      {
        print "file=$file dir=$PRINT_INTFBDIR $intfb : up-to-date\n";
      }
	
  }


chdir ($MKMAIN);

if (@all)
  {
    if (-s "$LOC_INTFBDIR/errorlog")
      {
        print ("EXPLICIT INTERFACE BLOCKS AUTO-GENERATOR ERROR\(S\) REPORTED IN :\n");
	&cat ("${LOC_INTFBDIR}/errorlog");
	print "Abort job.\n";
	chdir ($GMKWRKDIR);
	rmtree ($LOC_INTFBDIR);
	exit (1);
      }
    my $fh = 'FileHandle'->new (">$intfblist");
    find ({wanted => sub { m/\.intfb\.h$/o && $fh->print ("$File::Find::name\n") }, no_chdir => 1}, 
	  $GMKINTFB);
  }

chdir ($GMKWRKDIR);
rmtree ($LOC_INTFBDIR);


sub make_intfbl
{
  my ($file, $report) = @_;
# return system ("$GMKROOT/aux/make_intfbl.pl $file 1> $report 2>&1");


  my $stdout = 'FileHandle'->new ();
  my $stderr = 'FileHandle'->new ();

  # save STDOUT & STDERR in stderr, stdout
  open ($stderr, '>&', STDERR);
  open ($stdout, '>&', STDOUT);
 
  # redirect STDOUT & STDERR in report
  open (STDERR, '>', $report);
  open (STDOUT, '>&', STDERR);

  # run interface extraction

  use Data::Dumper;

  local $Data::Dumper::Indent = 1;

  eval {
    &make_intfbl1 ($file);
  };

  my $c = $@;
  
  # restore STDOUT & STDERR
  open (STDERR, '>&', $stderr);
  open (STDOUT, '>&', $stdout);
  $stderr->close ();
  $stdout->close ();

  return $c ? 1 : 0;
}

sub make_intfbl1
{
  use Fortran90_stuff;

  my @files = @_;

  &setup_parse();

  my $locintfbldir = $ENV{LOC_INTFBDIR} 
    or die "LOC_INTFBDIR not defined ";

  my $intfbldir = $ENV{INTFBDIR} 
    or die "INTFBDIR not defined ";

  our $study_called;

  for (@files) {
    my (@interface_block, @line_hash);
    chomp;
 # Read in lines from file
    my $fname = $_;
    print "Working on file $fname \n";
    my @lines = &readfile($fname);

    my (@statements,%prog_info);
    &expcont (\@lines,\@statements);

    $study_called=0;

    &study(\@statements,\%prog_info);

    print Dumper(\%prog_info);

    unless($prog_info{is_module}) 
      {
        &create_interface_block (\@statements,\@interface_block);
        &cont_lines (\@interface_block,\@lines,\@line_hash);
        my $int_block_fname = $fname;
        $int_block_fname =~ s/\.F90/.intfb.h/;
        $int_block_fname =~ s,.*/(.+)$,$1,;
        my $ofname = "$intfbldir/$int_block_fname";
        my $remake = 1;
        if (-f $ofname) 
	  {
            my @oldlines=&readfile($ofname);
            $remake=0 if (&eq_array(\@oldlines, \@lines));
            print "INTERFACE BLOCK $int_block_fname UNCHANGED \n" unless ($remake);
          }
        if ($remake) 
	  {
            print "WRITE INTERFACE BLOCK $int_block_fname \n";
            $int_block_fname = "$locintfbldir/$int_block_fname";
            print "$int_block_fname \n";
            &writefile ($int_block_fname,\@lines);
          }
      }
  }

}

sub eq_array 
{
  my ($ra, $rb) = @_;
  return 0 unless ($#$ra == $#$rb);
  for my $i (0 .. $#$ra) 
    {
      return 0 unless ($ra->[$i] eq $rb->[$i]);
    }
  return 1;
}


