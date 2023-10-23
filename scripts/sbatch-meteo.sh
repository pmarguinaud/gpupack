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

  ppack=$(basename $pack)

  out="$GPUPACK_PREFIX/cy49/arp/$grid/ref/$ppack/slurm.out"

  if [ -f "$out" ]
  then
  sbatch --exclusive --switches=3 -N$N -p $p  cy49/arp/arp.sh $pack $grid
  else
  mkdir -p $(dirname $out)
  sbatch --exclusive --switches=3 -o $out -N$N -p $p  cy49/arp/arp.sh $pack $grid
  fi
}


CYCLE=49t0
BRANCH=openacccpglag


for ARCH in NVHPC2309.1s NVHPC2309.1d INTEL1805.2s INTEL1805.2d
do
  for TRUNC in t0031 t0107 t0538 t0798
  do

    if [ "$ARCH" = "INTEL1805.2s" -o "$ARCH" = "INTEL1805.2d" ]
    then
      partition=normal256
    else
      partition=ndl
    fi
    
    if [ "$TRUNC" = "t0798" ]
    then
      nodes=3
    else
      nodes=1
    fi

    submit $nodes $partition cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.${ARCH} $TRUNC

  done
done
