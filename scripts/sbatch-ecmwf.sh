#!/bin/bash

. ./gpupack.sh

# Queue for parallel jobs
sbatch                                     -N2     -p par mpitest.sh $GPUPACK_PREFIX/pack/49t0_compile_with_pgi_2303-field_api.01.NVHPC2305.1s t0107

# Queue for GPU jobs; I have not managed to more than one node
sbatch --mem=247000 --ntasks-per-node 256  -N1 -G4 -p gpu mpitest.sh $GPUPACK_PREFIX/pack/49t0_compile_with_pgi_2303-field_api.01.NVHPC2305.1s t0107
