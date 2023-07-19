#!/bin/bash

set -x
set -e

. ./gpupack.sh

function submit ()
{
  N=$1
  p=$2
  script=$3
  pack=$4
  grid=$5
  
  if [ "$p" = "gpu" ]
  then
    sbatch \
      --partition gpu \
      --mem=247000 \
      --ntasks-per-node 256 \
      -N$N \
      --gres=gpu:4 \
      $script $pack $grid
  elif [ "$p" = "par" ]
  then
    sbatch \
      --partition par \
      -N$N \
      $script $pack $grid
  else
    exit 1
  fi
}

set -x

CYCLE=49t0
BRANCH=compile_with_pgi_2303-field_api

#ubmit 1 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1s t0031
#ubmit 1 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1d t0031

#ubmit 3 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1s t0798
submit 3 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1d t0798

exit

submit 1 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1s t0031
submit 1 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1d t0031

submit 3 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1s t0798
submit 3 gpu       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1d t0798

submit 1 par       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2s t0031
submit 1 par       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2d t0031

submit 3 par       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2s t0798
submit 3 par       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2d t0798


