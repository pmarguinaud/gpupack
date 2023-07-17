#!/usr/bin/env perl


sub arg_error {
  print STDERR shift, ": bad argument count\n";
  exit(1);
}


sub shell {

  &arg_error ( 'shell' ) if @_ <=> 1;

  my $cmd =  shift;
  my $out = `$cmd`; chomp $out;

  return $out;

}


sub CompareDate {

  my $file1 = shift;
  my $file2 = shift;

  return -1 unless -e $file2;
  return 1  unless -e $file1;

  $date1 = -M $file1;
  $date2 = -M $file2;

  return 1 if $date1 > $date2;
  return 0 if $date1 == $date2;
  return -1 if $date1 < $date2;

}


sub plEval {

  my $file = shift;

  if ( ! -e $file ) {
    print STDERR "Error in plEval: file '$file' not found\n";
    return 1;
  }

  my $content;

  open FILE, $file;
  { local($/) = undef; $content = <FILE>; chomp( $content ) }
  close FILE;

  my @c = split (m/\n/o, $content);

  for (@c)
    {
      eval ( $_ );
    }

  return 0;

}


sub diff_array {

  my %args = @_;

  my %tmp = ();
  my @array1 = sort grep { $tmp{$_}++ == 0 } @{$args{array1}};
  %tmp = ();
  my @array2 = sort grep { $tmp{$_}++ == 0 } @{$args{array2}};

  my %flag1;
  my %flag2;

  my @tmp;

  for ( @array1, @array2 ) { $flag2{$_} = 'false' }

  foreach $item1 ( @array1 ) {

    $flag1{$item1} = 'true';
    my @tmp = grep { $_ eq $item1 } @array2;

    if ( @tmp ) { foreach $item2 ( @tmp ) { $flag2{$item2} = 'true' } }

  }

  return (
	   common         => [ grep { $flag1{$_} eq 'true' && $flag2{$_} eq 'true' } @array1 ],
	   only_in_array1 => [ grep { $flag1{$_} eq 'true' && $flag2{$_} eq 'false' } @array1 ],
	   only_in_array2 => [ grep { $flag2{$_} eq 'false' } @array2 ]
         )

}


sub unique {

  my @array = @_;
  my %tmp = ();

  return ( grep { $tmp{$_}++ == 0 } @array );

}


sub tri_unique { return sort( &unique(@_) ) }


1;

