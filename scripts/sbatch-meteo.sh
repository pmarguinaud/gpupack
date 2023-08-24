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


  arch=$(perl -e ' use File::Basename; my $pack = shift; $pack = &basename ($pack); $pack =~ m/\.(\w+)\.(\w+)$/o; print $1 ' $pack)
  opt=$(perl -e ' use File::Basename; my $pack = shift; $pack = &basename ($pack); $pack =~ m/\.(\w+)\.(\w+)$/o; print $2 ' $pack)

  out="$GPUPACK_PREFIX/cy49/arp/$grid/ref/$arch.$opt/slurm.out"

  if [ -f "$out" ]
  then
  sbatch --exclusive --switches=3 -N$N -p $p  cy49/arp/arp.sh $pack $grid
  else
  mkdir -p $(dirname $out)
  sbatch --exclusive --switches=3 -o $out -N$N -p $p  cy49/arp/arp.sh $pack $grid
  fi
}


CYCLE=49t0
BRANCH=compile_with_pgi_2303-field_api

submit 1 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1s t0031
submit 1 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1d t0031

submit 3 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1s t0798
submit 3 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2305.1d t0798

exit

submit 1 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1s t0031
submit 1 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1d t0031

submit 3 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1s t0798
submit 3 ndl       cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.NVHPC2303.1d t0798

submit 1 normal256 cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2s t0031
submit 1 normal256 cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2d t0031

submit 3 normal256 cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2s t0798
submit 3 normal256 cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.INTEL1805.2d t0798


