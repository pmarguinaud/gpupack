#!/usr/bin/env perl  
#

=head1 NAME

gmak.pl

=head1 SYNOPSIS

gmak.pl -d          # create list of dependencies
gmak.pl comp_list   # create ordered list of files for compilation

=head1 HISTORY

Use strict and warnings

=head1 AUTHORS

stephane.martinez@meteo.fr, ryad.elkhatib@meteo.fr

=cut

use File::Find;
use FindBin qw($Bin);
use lib $Bin;

use strict;

require 'lib-file.pl';
require 'lib-shell.pl';

use Cwd;
use Data::Dumper;
use FileHandle;
use File::Basename;

#'FileHandle'->new ('>/tmp/gmak.pl')->print (Dumper ([\%ENV, \@ARGV, &cwd ()]));
#sleep(3600);


#
## Main
#

$| = 1;

our $GMKFILEPATH = $ENV{GMKFILEPATH};
our $GMKFILE     = $ENV{GMKFILE}; 
our $FLAVOUR     = $ENV{FLAVOUR}; 
our $GCOCONF     = "$GMKFILEPATH/$FLAVOUR";


our $GMK_EXEC_PATH = &cwd ();

# list of env variables

our @VARLIST = qw( MODINC MODEXT INC_PATH MKTOP MKMAIN MODE DEPSEARCH MKBRANCHES MKPROJECT SRC_NOTUSED DIR_NOTUSED );
our ($MODINC, $MODEXT, $INC_PATH, $DEPSEARCH, $SRC_NOTUSED, $MODE, $DIR_NOTUSED);

our @CONF_VARLIST = qw( MODINC MODEXT INC_PATH MODE DEPSEARCH SRC_NOTUSED DIR_NOTUSED );

our @LOC_VARLIST = qw( MODINC INC_PATH SRC_NOTUSED );


# read default parameters

our $GMKLOC;

&Eval( $GCOCONF );


# check env 

our $MKTOP      = $ENV{MKTOP};
our $MKMAIN     = $ENV{MKMAIN};
our $MKBRANCHES = $ENV{MKBRANCHES};
our $MKPROJECT  = $ENV{MKPROJECT} if $ENV{MKPROJECT};
our $GMKLOCAL   = $ENV{GMKLOCAL};
our $MKTMP      = $ENV{MKTMP};

Exit( '$MKTOP is undefined' ) unless $MKTOP;
Exit( "directory MKTOP=$MKTOP not found" ) unless -d $MKTOP;

( our $MKPACK = $MKTOP ) =~ s,/src$,,;
our $PACK   = &basename( $MKPACK );

Exit( "directory MKMAIN=$MKMAIN not found" ) unless -d $MKMAIN;

our $GMKLOCBR = &basename( $MKMAIN ) unless $GMKLOCBR;


# overwrite parameters with ENV variables

for ( @VARLIST ) {
  next unless (exists $ENV{$_});
  eval( '$' . $_ . ' = "' . $ENV{$_} . '"' )
      if ( $ENV{$_} ne ""
           && $_ ne 'MKTOP'
           && $_ ne 'MKMAIN'
           && $_ ne 'MKBRANCHES'
           && $_ ne 'MKPROJECT' )
}


# hash for local use

our %GMKLOC = ();
&reset_loc;


# hash for files' properties

our %GMKFPROP = ();
our %GMKNAME  = ();
our %GMKMTIME = ();
our %GMKISMOD = ();


# arrays for files' lists

our @GMKTOPLIST   = ();
our @GMKDEPLIST   = ();
our @GMKOTHERLIST = ();
our @COMP_LIST    = ();

our $flag_comp = 0;

our %GMKFLAGDEP  = ();
our %GMKFLAGCOMP = ();
our %GMKFLAGERR  = ();
our $GMKDIR = '';


# paths for modules

our @MOD_PATH = ();


# check coherence between MKMAIN and MKBRANCHES 

my $locbr1 = &basename( $MKMAIN );
my $locbr2 = do { my @tmp = split /\s+/, $MKBRANCHES; $tmp[@tmp-1] };

Exit( "Incoherence between \$MKMAIN and \$MKBRANCHES:\nMKMAIN=$MKMAIN\nMKBRANCHES=$MKBRANCHES" )
  if $locbr1 ne $locbr2;


# logfile

our $LOGFILE = "$MKMAIN/gmak.log";


# list mode ( equal to 1 if files are compiled from an ordered list )

our $LISTMODE = 0;


# read args

our @COMP_ARGS = ();

my $run = 1;
our $GETCOMPLIST = "";

while ( @ARGV ) {

  my $arg = $ARGV[0];

  if ( $arg eq '-d' || $arg eq 'depend' ) { $run = 0; shift( @ARGV ); &mk_depend }

  elsif ( $arg eq 'comp_list' ) { $run = 0; shift( @ARGV ); $GETCOMPLIST = "c"; &get_comp_list }

  elsif ( $arg eq 'mod_list' ) { $run = 0; shift( @ARGV ); $GETCOMPLIST = "m"; &get_comp_list }

}



#
## SUB Exit: exit if error 
#

sub Exit {
  my $msg = shift;
  print STDERR "gmak: Error: $msg\n";
  exit(1); 
}


#
## SUB Warn: send a warning to standard error output
#

sub Warn {
  my $msg = shift;
  print STDERR "gmak: Warning: $msg\n"; 
}


#
## SUB Eval: read parameters from a file 
#

sub Eval {

  my $file = shift;
  my $content = &cat( $file );

  $content =~ s/\s+\\\n\s*/ /g;

  my @LIST;

  if ( $file eq $GCOCONF ) { @LIST = @VARLIST }
  else { @LIST = @CONF_VARLIST }

  my @cmd  = split /\n/, $content;

  for ( @cmd ) {

    if ( $_ !~ /^#/ && $_ !~ /^\s*$/ ) {

      $_ =~ s/^\s*//;
      $_ =~ s/\s*$//;
      $_ =~ s/\$\*/\\\$\\\*/g;

      my ( $param, $value ) = ( $_ =~ /^(\w+)\s*=\s*(.*)$/ );

      if ( grep { $_ eq $param } @LIST ) {
        eval ( '$' . $param . ' = "' . $value . '"' );
        eval ( '$GMKLOC{"' . $param . '"} = "' . $value . '"' );
      }
      elsif ( $file ne $GCOCONF ) { &Warn( "'$param' can't be modified in file '$file'" ) }

    }

  }

}


#


#
## SUB reset_loc: reset hash GMKLOC
#

sub reset_loc {

  %GMKLOC = ();

  $GMKLOC{'MODINC'}      = $MODINC;
  $GMKLOC{'MODEXT'}      = $MODEXT;
  $GMKLOC{'INC_PATH'}    = $INC_PATH;
  $GMKLOC{'MKTOP'}       = $MKTOP;
  $GMKLOC{'MKMAIN'}      = $MKMAIN;
  $GMKLOC{'MKPACK'}      = $MKPACK;
  $GMKLOC{'MKPROJECT'}   = $MKPROJECT;
  $GMKLOC{'MODE'}        = $MODE;
  $GMKLOC{'DEPSEARCH'}   = $DEPSEARCH;
  $GMKLOC{'MKBRANCHES'}  = $MKBRANCHES;
  $GMKLOC{'SRC_NOTUSED'} = $SRC_NOTUSED;
  $GMKLOC{'DIR_NOTUSED'} = $DIR_NOTUSED;

}


#
#

#
## SUB getdeps: get dependencies
#

sub getdeps {

  my $file   = shift;
  my $branch = $GMKFPROP{$file}{branch};
  my $base   = &basename( $file );

  if ( ! $branch ) {
    $GMKFPROP{$file}{branch} = $GMKLOCBR;
    $branch = $GMKLOCBR;
  }

  my $content  = &cat( "$MKTOP/$branch/$file" );
  my $isModule = 0;
  my $modname;

  ( $modname ) = ( $content =~ /^\s*module\s+([\w\-]+)/im );
  $modname = '' if ( "$modname" =~ /^procedure$/i );

  if ( $modname ) { $isModule = 1 }
  else { ( $modname ) = ( $base =~ /^(.*)\.(c|f|F|f90|F90|h|inc|sql|cc|cpp|ddl)$/ ) }

  $modname =~ tr/A-Z/a-z/;

  $MODEXT  = $GMKLOC{'MODEXT'};
  my @mod  = map { ( my $mod = $_ ) =~ tr/A-Z/a-z/;"$mod.$MODEXT" } ( $content =~ /^\s*use\s+([\w\-]+).*$/img );
  my @smod = map { ( my $mod = $_ ) =~ tr/A-Z/a-z/;"$mod.$MODEXT" } ( $content =~ /^\s*submodule\s*\(\s*(\w+)\s*\)\s*\w+/img );
  my @inc1 = ( $content =~ /^\s*#include\s*"([\w\-\.\/]+\.h)"/mig );
  my @inc2 = ( $content =~ /^\s*include\s*'([\w\-]+\.inc)'/mig );
  my @inc3 = ( $content =~ /^\s*include\s*"([\w\-]+\.h)"/mig );
  my @inc  = ( @inc1, @inc2, @inc3 );

  #  map { $_ =~ s/\.(h|inc)$/\.ok/ } @inc;
  map {
        $_ =~ s/\.(h|inc)$/\.ok/;
        $_ = &basename($_);
      } @inc;

  push(@mod,@smod);
  @mod = &tri_unique( @mod );
  @inc = &tri_unique( @inc );

  my %out = (
              mod     => [ @mod ],
              inc     => [ @inc ],
              modname => $modname,
              module  => $isModule
            );

  return %out;

}

#
## SUB mk_depend: create dependencies file
#

sub mk_depend {

  if (-f "$MKTMP/local.sds")
    {
      do ("$MKTMP/local.sds");
    }


  open DEP, ">$MKTMP/local.sds" or Exit( "Can't open > $MKTMP/local.sds" );

  print ">  Creating list of dependencies ...\n";

  my $olddir = '';
  my @list = split /\n/, &cat( "$MKTMP/packlist" );

  foreach my $file ( @list ) {

    my $base = &basename( $file );
    my $dir  = &dirname( $file );

    if ( $olddir ne $dir ) {
      &reset_loc;
      chdir ( "$MKMAIN/$dir" );
      $olddir = $dir;
    }

    print "  > $file\n";

    my $content = &cat( $base );

    my $branch = $GMKLOCBR;
    my $mtime    = &mtime ("$MKTOP/$branch/$file");

    my ($inc, $modname, $isModule);


    if (($GMKMTIME{$file} || 0) < $mtime)
      {
	# file has changed; read its contents again
        my %filedeps = &getdeps( $file );
        $modname  = $filedeps{modname};
        $isModule = $filedeps{module};
        $inc = join (",", map { "'$_'" } (@{$filedeps{mod}}, @{$filedeps{inc}}));
      }
    else
      {
        # use values read from local.sds
        $modname  = $GMKFPROP{$file}{modname};
	$isModule = $GMKISMOD{$file};
	$inc      = join (",", (map { "'$_'" } @{$GMKFPROP{$file}{deps}}));
      }

    local $SIG{__WARN__} = sub { 
       print Dumper([file => $file, branch => $branch, modname => $modname, inc => $inc, mtime => $mtime]);
       die ("@_")
    };


    if ( $isModule ) {
      print DEP "\$GMKFPROP{'$file'}{modname} = '$modname'; "
               ."\$GMKFPROP{'$file'}{branch} = '$branch'; "
	       ."\@{\$GMKFPROP{'$file'}{deps}} = ( $inc ); "
	       ."\$GMKMTIME{'$file'} = $mtime; "
	       ."\$GMKISMOD{'$file'} = 1; "
	       ."\$GMKNAME{'$modname'} = '$file';\n";
    }
    else {
      print DEP "\$GMKFPROP{'$file'}{modname} = '$modname'; "
               ."\$GMKFPROP{'$file'}{branch} = '$branch'; "
	       ."\$GMKMTIME{'$file'} = $mtime; "
	       ."\@{\$GMKFPROP{'$file'}{deps}} = ( $inc );\n";
    }

  }

  &reset_loc;
  close DEP;

}


#
#
## SUB mk_dep_list: dependencies search
#

our @GMKDEPS;

sub mk_dep_list {

  print ">  Searching dependencies...\n";

  @GMKDEPS = ();

  for (keys (%GMKFPROP))
    { 
      push( @GMKDEPS, "$_:$GMKFPROP{$_}{modname}: @{$GMKFPROP{$_}{deps}}" ) 
    }

  @GMKDEPLIST = ();

  for my $file ( @GMKTOPLIST ) {
    if ( (!$GMKFLAGDEP{$file}) && $GMKFLAGCOMP{$file} ) 
      { 
	&deps( $file );
      }
    $GMKFLAGDEP{$file} = 1;
  }

  my %tmp = (); 
  @GMKDEPLIST = grep { $tmp{$_}++ == 0 } @GMKDEPLIST;

}


#
## SUB deps: search for a file's dependencies
#

sub deps {

  my $fullname = shift;
  my $deck     = &basename( $fullname );
  my $base;
  my $suff;
  my $mod;
  my $dep;

  print "  > dependencies of $fullname ...\n";

  $GMKFLAGDEP{$fullname} = 1;

  print "    > $fullname from '$GMKFPROP{$fullname}{branch}'\n";

  if ( $deck =~ /^(.*)\.(f|F|f90|F90|h|inc)$/ ) {

    $base = $1;
    $suff = $2;

    if ( $suff eq 'h' || $suff eq 'inc' ) { $dep = "$base.ok" }

    else {
     
      $dep = "$GMKFPROP{$fullname}{modname}.$MODEXT";

#     my $dir = &dirname( $fullname );
#     if ( $dir =~ /module/ ) { $dep = "$GMKFPROP{$fullname}{modname}.$MODEXT" }
#     else { $dep = "$base.$MODEXT" }

    };

    my @deps = map { transform($_) } grep { index( $_, " $dep" ) >= 0 } @GMKDEPS;
    @deps = grep { my $proj = (split /\//)[0]; $MKPROJECT =~ /\s*$proj\s*/ } @deps;

    for ( @deps ) { print "    > $_ from '$GMKFPROP{$_}{branch}'\n" }

    push( @GMKDEPLIST, @deps );

    for ( @deps ) {
      if ( is_module($_) ) {
        &deps( $_ ) if (!$GMKFLAGDEP{$_});
      }
    }

  }

}


sub transform {  return (split /:/, shift)[0] };



#
## SUB mk_files_properties: get files' properties
#
#

our @COMPLIST;

sub mk_files_properties {

  print ">  Read dependencies ...\n";

  foreach my $branch ( split /\s+/, $MKBRANCHES ) {

    my $GMKDEP = $branch eq $GMKLOCBR
               ? "$MKTMP/$branch.sds"
               : "$MKTOP/.gmak/$branch.sds";

#   print "$branch -> $GMKDEP\n"; 

    my $coderep = &plEval( $GMKDEP );
    Exit( "File '$GMKDEP' not found" ) if ($coderep);

    if ( $branch eq $GMKLOCBR && ! @_ )
      { 
	@COMPLIST = grep { $GMKFPROP{$_}{branch} eq $branch } 
	            keys (%GMKFPROP);
      }

  }

}

#
#
## SUB get_gmk_env: return a gmak's env variable
#

sub get_gmk_env {

  my $param = shift;

  if ( $param eq 'INC_PATH' ) {
    &get_inc_path;
    return;
  }

  print "$param=\"$GMKLOC{$param}\"\n";

}



#
## SUB ord_top_list
#

sub ord_top_list {
  for my $file (@GMKTOPLIST) 
    {
      &find_and_flag($file) 
        if (!$GMKFLAGCOMP{$file});
      $GMKFLAGCOMP{$file} = 1;
    }
}


#
## SUB ord_dep_list
#

sub ord_dep_list {
  my $branch = '';
  foreach my $file ( @GMKOTHERLIST ) {
    $branch = $GMKFPROP{$file}{branch};
    if (!$GMKFLAGCOMP{$file}) {
      push( @COMP_LIST, "$file $branch" );
    }
    $GMKFLAGCOMP{$file} = 1; 
  }
}


sub ord_other_list {
  my $branch = '';
  foreach my $file ( @GMKOTHERLIST ) {
    $branch = $GMKFPROP{$file}{branch};
    if (!$GMKFLAGCOMP{$file}) {
      push( @COMP_LIST, "$file $branch" );
    }
    $GMKFLAGCOMP{$file} = 1;
  }
}


#
## SUB find_and_flag
#

sub find_and_flag {

  my $file = shift;
  return unless $file;

  my $base = '';
  my $modf = '';

  LOOP_DEPS: for my $dep (@{$GMKFPROP{$file}{deps}}) 
    {

      if ( $dep =~ /\.ok$/ ) {
        $base = &basename( $dep, '.ok' );
        ( $modf ) = grep /\/$base\.(?:h|inc)/, @GMKTOPLIST;
      }
      elsif ( $dep =~ /\.$MODEXT$/ ) {
        $base = &basename( $dep, ".$MODEXT" );

	if ($GMKNAME{$base})
	  {
            ( $base = &basename( $GMKNAME{$base} ) ) =~ s/\./\\\./g;
            ( $modf ) = grep /\/$base$/, @GMKTOPLIST;
	  }
      }
      else { 
         next LOOP_DEPS 
      }

      next LOOP_DEPS unless $modf;
      next LOOP_DEPS if ($modf eq $file);

      find_and_flag ($modf)
        if (!$GMKFLAGCOMP{$modf});

    }

  if (!$GMKFLAGCOMP{$file}) {
    push( @COMP_LIST, "$file $GMKFPROP{$file}{branch}" );
    $GMKFLAGCOMP{$file} = 1;
  }

}


#
## SUB get_comp_list: get ordered list for compilation
#

sub get_comp_list {

  my %tmp = ();	

  &mk_files_properties( @_ );
  @COMPLIST = @_ if @_;

  for ( @COMPLIST ) {
    if ( &is_module($_) ) 
      { 
        push( @GMKTOPLIST, $_ );
      }
    else 
      { 
        push( @GMKOTHERLIST, $_ );
      }
  }


  if ( @GMKTOPLIST ) {

    &ord_top_list;

    if ( $DEPSEARCH ) {

      &mk_dep_list;

      if ( @GMKDEPLIST ) {

        my @TMPLIST = @GMKOTHERLIST;

        @GMKOTHERLIST = ();

	for ( @GMKDEPLIST ) {
          if ( is_module($_) ) { push( @GMKTOPLIST, $_ ) }
          else { push( @GMKOTHERLIST, $_ ) }
        }

	@GMKTOPLIST = grep { $tmp{$_}++ == 0 } @GMKTOPLIST;

        my $OLD_DEPSEARCH = $DEPSEARCH;
        $DEPSEARCH     = 0;

	unless ( $MKBRANCHES eq $GMKLOCAL ) {
          if ( @GMKTOPLIST ) {
            %GMKFLAGCOMP = ();
	    foreach my $item ( @GMKTOPLIST ) { @COMP_LIST = grep !/^$item /, @COMP_LIST }
            &ord_top_list;
          }
	}

        $DEPSEARCH = $OLD_DEPSEARCH;

        &ord_dep_list if (@GMKOTHERLIST && $GETCOMPLIST eq "c");

	@GMKOTHERLIST = @TMPLIST;

        @TMPLIST = ();

      }

    }

  }
  
  &ord_other_list if (@GMKOTHERLIST && $GETCOMPLIST eq "c");

  %tmp = ();
  #@COMP_LIST = grep { $_ ne "" && $tmp{$_}++ == 0 } @COMP_LIST;
  #@COMP_LIST = grep !/^\s*$/, @COMP_LIST;
  @COMP_LIST = grep { $tmp{$_}++ == 0 } @COMP_LIST;

  my $listname = $GETCOMPLIST eq "c"
               ? "$MKTMP/comp_list"
	       : "$MKMAIN/mod_list";

  open COMPLIST, ">$listname";
  for ( @COMP_LIST ) { print COMPLIST "$_\n" }
  close COMPLIST;

  print ">  Ordered list in file $listname\n";

}


#
#
## sub is_module: test if a file is a module (or an include)
#
#


my %IS_MODULE; # cache

sub is_module {

  my $file = shift;

  unless (exists ($IS_MODULE{$file}))
    {

      if ($file =~ /\.(h|inc)$/o)
        {
          $IS_MODULE{$file} = 1;
        }
      elsif ($file =~ /\.(c|sql|cc|cpp|ddl)$/o)
        {
          $IS_MODULE{$file} = 0;
        }
      else
        {
          my $content = &cat( "$MKTOP/$GMKFPROP{$file}{branch}/$file" );
          $IS_MODULE{$file} = $content =~ /^\s*module\s+/im ? 1 : 0;
        }
    }

  return $IS_MODULE{$file};
}


