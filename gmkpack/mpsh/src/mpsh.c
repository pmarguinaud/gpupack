/*
 * mpsh:
 * 
 *  Message Passing Shell
 *  ---------------------
 *
 *  Execute mpsh.job.xxxx shell jobs. Start with job number = mpi rank
 *  and then any remaining job according to a pseudo-lock strategy.
 *  ( thanks to pascal.lamboley@meteo.fr )
 *
 *  (copyleft) 2004 eric.sevault@meteo.fr
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>

#include "mpi.h"

int main ( int argc, char **argv ) {

  char        filename[14];
  char        filecopy[15];
  char        cmd[255];
  char        *shell, *jobs;
  struct stat buf;
  int         irank = 0;
  int         ijob, ierr, iproc, njobs;

  shell = getenv( "SHELL" );
  jobs  = getenv( "MPSH_JOBS" );
  njobs = atoi( jobs );

  fprintf( stderr, "mpsh: start %s session with %d jobs\n", shell, njobs );

  ierr = MPI_Init( &argc, &argv );

  ierr = MPI_Comm_rank( MPI_COMM_WORLD, &irank );

  fprintf( stderr, "mpsh: rank %d ( mpi status %d )\n", irank, ierr );

  MPI_Comm_size( MPI_COMM_WORLD, &iproc );

  fprintf( stderr, "mpsh: comm size %d ( mpi status %d )\n", iproc, ierr );

  for ( ijob=irank; ijob<njobs; ijob++ ) {
    sprintf( filename, "mpsh.job.%04d", ijob );
    if ( stat( filename, &buf ) ) {
      fprintf( stderr, "mpsh: proc %d no more job %s\n", irank, filename );
    } else {
      sprintf( filecopy, "mpsh.%04d.%04d", ijob, irank );
      if ( rename( filename, filecopy ) ) {
        fprintf( stderr, "mpsh: proc %d job %s used elsewhere\n", irank, filename );
      } else {
        if ( stat( filecopy, &buf ) ) {
          fprintf( stderr, "mpsh: proc %d copy %s not found\n", irank, filecopy );
        } else {
          sprintf( cmd, "%s %s 2>&1", shell, filecopy, filename );
          ierr = system( cmd );
          fprintf( stderr, "mpsh: proc %d exec %s returns %d\n", irank, filename, ierr );
          remove( filecopy );
          if ( ierr ) {
            fprintf( stderr, "mpsh: proc %d abort %s\n", irank, filename );
            fflush( stderr );
            MPI_Abort( MPI_COMM_WORLD, ierr );
          }
        }
      }
    }
  }

  fprintf( stderr, "mpsh: proc %d nothing more to do...\n", irank );
  fflush( stderr );

  MPI_Finalize();
}
