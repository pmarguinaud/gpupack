#!/usr/bin/perl

use File::Find;
use File::Basename;
use Carp qw (croak);


$HANDLER_IN  = 'HIGHLY_IMPROBABLE_HANDLER_NAME_IN';
$HANDLER_OUT = 'HIGHLY_IMPROBABLE_HANDLER_NAME_OUT';


sub cp {

  croak ("cp Insufficient arguments\n") if @_ < 2;

  my $targ;
  my $outfile;
  my $content;

  my $target = pop();

  croak ("cp Target $target must be a directory\n") if -f $target &&  @_ > 1;

  if ( -d $target ) { $targ = 'dir' }
  else { $targ = 'file' }

  for ( @_ ) {

    if ( $targ eq 'file' ) { $outfile = $target }
    else { $outfile = $target . '/' . &basename($_) }

    if ( open $HANDLER_OUT, ">$outfile" ) {
      $content = &cat( $_ );
      if ( -f $_ ) {
        print $HANDLER_OUT "$content\n";
        close $HANDLER_OUT;
      }
    }

    else { croak ("cp cannot create $outfile\n") }

  }

}


sub cpdir {

  croak ("cpdir Insufficient arguments\n") if @_ < 2;

  my $target = pop();

  if ( ! -d $target ) { croak ("cpdir $target not found\n") if @_ > 1 }

  my @list;
  my $oldpwd;

  $oldpwd = &pwd();
  my $locdir;
  my $basedir;

  foreach $dir ( @_ ) {

    if ( $dir =~ /\// ) { $locdir = $dir }
    else { $locdir = "$oldpwd/$dir" }

    if ( chdir( "$locdir" ) ) {
    &find( sub {
                  $FILE = $File::Find::name;
                  push( @list, "$locdir/$FILE" ) if -f "$locdir/$FILE";
                }, "." ) }
     else { croak ("cpdir cannot access $dir\n") }

  }

  chdir( $oldpwd );

  my $base;
  my $name;
  my $dir;
  my $flag_del_target;

  foreach $file ( @list ) {

    ( $base, $name ) = split m!/\./!, $file;

    if ( $target eq '' ) { $target = &basename( $base ) }

    if ( -d $target ) {
      $flag_del_target = 0;
      $target = &basename( $base );
    }
    else { $flag_del_target = 1 }
    
    $dir = $target . '/' . &dirname( $name );

    $target = '' if $flag_del_target;

    &Mkdir( $dir ) unless -d $dir;
    &cp( $file, $dir );

  }

}


sub mv {

  &cp( @_ );
  pop();
  unlink( @_ );

}


sub rm {

  if ( ! @_ ) { croak ("rm Insufficient arguments\n") }
  else { for ( @_ ) { unlink( $_ ) or croak ("rm $_: No such file or directory\n") } }

}


sub cat {

  my $cat;

  if ( ! @_ ) { croak ("cat Insufficient arguments\n") }
  
  else {

    my $content;

    for ( @_ ) {

      if ( open $HANDLER_IN, $_ ) {
	{ local($/) = undef; $content = <$HANDLER_IN> }
	$cat .= $content;
        close( $HANDLER_IN );
      }

      else { croak ("cat: cannot open $_\n") }

    }

  }

  chomp( $cat );
  return $cat;

}


sub ls {

  my @list;
  my @tmp;

  if ( ! @_ ) {

    if ( opendir $HANDLER_IN, '.' ) {
      @list = sort grep !/^\.{1,2}$/, readdir( $HANDLER_IN );
      close $HANDLER_IN;
    }

    else { croak ("ls : No such file or directory\n") }

  }

  else {

    for ( @_ ) {

      if ( opendir $HANDLER_IN, $_ ) {
        @tmp = sort grep !/^\.{1,2}$/, readdir( $HANDLER_IN );
        close $HANDLER_IN;
	push( @list, @tmp )
      }

      else { croak ("ls $_ No such file or directory\n") }

    }

  }

  return @list;

}


sub lsdir {

  my @list;
  my @tmp;

  if ( @_ ) {

    foreach $dir ( @_ ) {
      @tmp = grep { -d "$dir/$_" } &ls( $dir );
      push( @list, @tmp );
    }

  }

  else { @list = grep { -d "./$_" } &ls() }

  return @list;

}


sub lsfile {

  my @list;
  my @tmp;

  if ( @_ ) {

    foreach $dir ( @_ ) {
      @tmp = grep { -f "$dir/$_" } &ls( $dir );
      push( @list, @tmp );
    }
  
  }

  else { @list = grep { -f "./$_" } &ls() }

  return @list;

}


sub lslink {

  my @list;
  my @tmp;

  if ( @_ ) {

    foreach $dir ( @_ ) {
      @tmp = grep { -l "$dir/$_" } &ls( $dir );
      push( @list, @tmp );
    }

  }

  else { @list = grep { -l "./$_" } &ls() }

  return @list;

}


sub Mkdir {

  if ( ! @_ ) { croak ("Mkdir usage: Mkdir( dir1, dir2, ... )\n" ) }

  else {

    my $dir;

    foreach $d ( @_ ) {

      if ( $d =~ m!^/! ) { $dir = '/' }
      else { $dir = '' }

      for ( split /\//, $d ) {

        if ( $dir eq '' ) { $dir = $_ }
        else { $dir = "$dir/$_" }

        if ( ! -d $dir ) { mkdir( $dir, 0755 ) }

      }

    }

  }

}


sub suffix {

  if ( @_ <=> 1 ) { croak ("suffix : Bad argument count\n") }

  my @tmp = split /\./, shift;
  my $suff = pop( @tmp );
 
  return $suff;

}


sub pwd {
  if ( @_ <=> 0 ) { croak ("Bad argument count") }
  return $ENV{PWD};
}


sub finddir {

  my @list;
  my $file;

  &find( sub {
                $file = $File::Find::name;
                -d $file && push( @list, $file );
             }, @_ );

  return @list;

}

sub mtime
{
  my $f = shift;
  return (stat ($f))[9];
}


1;
