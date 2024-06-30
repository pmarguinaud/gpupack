#!/bin/bash

module () 
{ 
  eval `/usr/bin/modulecmd bash $*`
}
module purge 2>/dev/null
module load intel/oneapi/2023.2 2>/dev/null
module load compiler/2023.2.0 2>/dev/null
module load mkl/2023.2.0 2>/dev/null
module load mpi/2021.10.0 2>/dev/null
module load gcc/5.3.0 2>/dev/null


