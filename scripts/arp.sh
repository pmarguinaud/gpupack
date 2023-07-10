#!/bin/bash

set -x
set -e

function submit ()
{
  N=$1
  p=$2
  script=$3
  arch=$4
  opt=$5
  grid=$6

  out="$HOME/gpupack/cy49/arp/$grid/ref/$arch.$opt/slurm.out"
  
  if [ -f "$out" ]
  then
  sbatch -N$N -p $p  cy49/arp/arp.sh $arch $opt $grid
  else
  mkdir -p $(dirname $out)
  sbatch -o $out -N$N -p $p  cy49/arp/arp.sh $arch $opt $grid
  fi
}


submit 1 ndl       cy49/arp/arp.sh NVHPC2303 1s t0031
submit 1 ndl       cy49/arp/arp.sh NVHPC2303 1d t0031

submit 3 ndl       cy49/arp/arp.sh NVHPC2303 1s t0798
submit 3 ndl       cy49/arp/arp.sh NVHPC2303 1d t0798

submit 1 normal256 cy49/arp/arp.sh INTEL1805 3s t0031
submit 1 normal256 cy49/arp/arp.sh INTEL1805 3d t0031

submit 3 normal256 cy49/arp/arp.sh INTEL1805 3s t0798
submit 3 normal256 cy49/arp/arp.sh INTEL1805 3d t0798


