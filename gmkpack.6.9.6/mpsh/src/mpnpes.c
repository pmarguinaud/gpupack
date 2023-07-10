/*
 * mpshnpe:
 * 
 *  Message Passing Shell
 *  ---------------------
 *
 *  Returns the total number of processing elements in the current communicator
 *
 *  (copyleft) 2005 eric.sevault@meteo.fr
 *
 */

#include <stdio.h>
#include <stdlib.h>

#include "mpi.h"

int main ( int argc, char **argv ) {

  int ierr, irank, iproc;

  ierr = MPI_Init( &argc, &argv );

  ierr = MPI_Comm_rank( MPI_COMM_WORLD, &irank );

  ierr = MPI_Comm_size( MPI_COMM_WORLD, &iproc );

  if ( irank == 0 ) {
    fprintf( stdout, "%d\n", iproc, ierr );
    fflush( stdout );
  }

  MPI_Finalize();
}
