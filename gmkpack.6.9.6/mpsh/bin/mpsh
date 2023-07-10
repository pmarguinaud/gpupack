#!/usr/bin/perl  -w

# mpsh:

#  Message Passing Shell using Threads
#  -----------------------------------

# (copyleft) 2006 eric.sevault@meteo.fr


use strict;
use threads;

my $shell = $ENV{SHELL}
  or die "mpsh: undefined value SHELL\n";

my $njobs = $ENV{MPSH_JOBS}
  or die "mpsh: undefined value MPSH_JOBS\n";

my $npes = $ENV{MPSH_NPES}
  or die "mpsh: ndefined value MPSH_NPES\n";

my @sons = ();

sub mpilike {
  my ( $shell, $rank, $njobs, $np ) = @_;

  my $tid = threads->self->tid();

  local $| = 1;

  print STDERR "mpsh: rank $rank ( tid value $tid )\n";

  for ( my $job=$rank; $job<$njobs; $job++ ) {
    my $filename = sprintf "mpsh.job.%04d", $job;
    if ( not stat( $filename ) ) {
      printf STDERR "mpsh: proc %d no more job %s\n", $rank, $filename;
    } else {
      my $filecopy = sprintf "mpsh.%04d.%04d", $job, $rank;
      if ( not rename( $filename, $filecopy ) ) {
        printf STDERR "mpsh: proc %d job %s used elsewhere\n", $rank, $filename;
      } else {
        if ( not stat( $filecopy ) ) {
          printf STDERR "mpsh: proc %d copy %s not found\n", $rank, $filecopy;
        } else {
          my $err = system( "export TID=$tid; $shell $filecopy 2>&1" );
          printf STDERR "mpsh: proc %d exec %s returns %d\n", $rank, $filename, $err;
          unlink $filecopy;
          if ( $err ) {
            printf STDERR "mpsh: proc %d abort %s\n", $rank, $filename;
      	    system( "cp $filename.err 2>&1" );
	    return 0;
          }
        }
      }
    }
  }

  print STDERR "mpsh: proc $rank nothing more to do...\n";

  return 1;
}

for ( my $i=0; $i<$npes; $i++) {
  push @sons, threads->create( 'mpilike', $shell, $i, $njobs, $npes );
}

my $status = 1;

$status &&= $_->join() for ( @sons );

exit( 1 - $status );
