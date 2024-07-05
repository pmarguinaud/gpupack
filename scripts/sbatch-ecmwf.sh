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
    if [ "$p" = "gpu" ]
    then
      sbatch --partition gpu --mem=247000 --ntasks-per-node 256 -N$N --gres=gpu:4 $script $pack $grid
    else
      sbatch --partition par -N$N $script $pack $grid
    fi
  else
    mkdir -p $(dirname $out)
    if [ "$p" = "gpu" ]
    then
      sbatch -o $out --partition gpu --mem=247000 --ntasks-per-node 256 -N$N --gres=gpu:4 $script $pack $grid
    else
      sbatch -o $out --partition par -N$N $script $pack $grid
    fi
  fi
}


set -x

CYCLE=49t2
BRANCH=openacc



for ARCH in NVHPC2405ECTRANSGPU.1d NVHPC2405ECTRANSGPU.1s NVHPC2405.1d NVHPC2405.1s INTEL2302.2s INTEL2302.2d
do
  for TRUNC in t0031 t0107 t0538 t0798
  do

    if [ ${ARCH:0:5} = "INTEL" ]
    then
      partition=par
    else
      partition=gpu
    fi

    if [ "$TRUNC" = "t0798" ]
    then
      nodes=3
    elif [ "$TRUNC" = "t0538" ]
    then
      nodes=2
    else
      nodes=1
    fi

    submit $nodes $partition cy49/arp/arp.sh $GPUPACK_PREFIX/pack/${CYCLE}_${BRANCH}.01.${ARCH} $TRUNC

  done
done
