#!/bin/bash
#SBATCH --export=NONE
#SBATCH --job-name=arp
#SBATCH --nodes=1
#SBATCH --time=00:25:00
#SBATCH --exclusive
#SBATCH --verbose
#SBATCH --no-requeue
#SBATCH -p ndl

set -x

function grib_api_setup ()
{
  bin=$1

  # Set up grib_api environment

  grib_api_prefix=$(ldd $bin  | perl -ne ' 
   next unless (m/libeccodes_f90/o); 
   my ($path) = (m/=>\s+(\S+)/o); 
   use File::Basename; 
   print &dirname (&dirname ($path)), "\n" ')
  export GRIB_DEFINITION_PATH=$PWD/extra_grib_defs:$grib_api_prefix/share/definitions:$grib_api_prefix/share/eccodes/definitions
  export GRIB_SAMPLES_PATH=$grib_api_prefix/ifs_samples/grib1:$grib_api_prefix/share/eccodes/ifs_samples/grib1
}

function nominal_setup ()
{
  pack=$1
  \rm -f lparallelmethod.txt  lsynchost.txt
  export INPART=0
  export PERSISTENT=0
  export PARALLEL=0
  unset LPARALLELMETHOD_VERBOSE
  unset CLSTACKSIZE
}

function openmp_setup ()
{
  pack=$1
  \rm -f lparallelmethod.txt  lsynchost.txt
  export INPART=1
  export PERSISTENT=1
  export PARALLEL=1
  unset LPARALLELMETHOD_VERBOSE
  unset CLSTACKSIZE
  cp $pack/lparallelmethod.txt.OPENMP lparallelmethod.txt
}

function openmpsinglecolumn_setup ()
{
  pack=$1
  \rm -f lparallelmethod.txt  lsynchost.txt
  export INPART=1
  export PERSISTENT=1
  export PARALLEL=1
  unset LPARALLELMETHOD_VERBOSE
  export CLSTACKSIZE=65
  cp $pack/lparallelmethod.txt.OPENMPSINGLECOLUMN lparallelmethod.txt
}

function openaccsinglecolumn_setup ()
{
  pack=$1
  \rm -f lparallelmethod.txt  lsynchost.txt
  export INPART=1
  export PERSISTENT=1
  export PARALLEL=1
  export LPARALLELMETHOD_VERBOSE=1
  export CLSTACKSIZE=65
  cp $pack/lparallelmethod.txt.OPENACCSINGLECOLUMN lparallelmethod.txt
}


# Environment variables

ulimit -s unlimited
export OMP_STACKSIZE=4G
export KMP_STACKSIZE=4G
export KMP_MONITOR_STACKSIZE=1G
export DR_HOOK=1
export DR_HOOK_IGNORE_SIGNALS=-1
export DR_HOOK_OPT=prof
export EC_PROFILE_HEAP=0
export EC_MPI_ATEXIT=0
export MKL_CBWR=AUTO,STRICT
export MKL_DEBUG_CPU_TYPE=5
export MKL_NUM_THREADS=1

export PATH=$HOME/gpupack/scripts:$PATH

# Change to a temporary directory

export workdir=/scratch/work/marguina

if [ "x$SLURM_JOBID" != "x" ]
then
export TMPDIR=$workdir/tmp/arp.$SLURM_JOBID
else
export TMPDIR=$workdir/tmp/arp.$$
fi

mkdir -p $TMPDIR

cd $TMPDIR

export PACK=$HOME/gpupack/pack/49t0_compile_with_pgi_2303-field_api.01.NVHPC2303.xd  
export GRID=t0031
export DATADIR=/home/gmap/mrpm/marguina/gpupack/cy49

for method in nominal openmp openmpsinglecolumn openaccsinglecolumn
do

# Spawn new shell
(
  mkdir -p $method
  cd $method
  
  for f in $DATADIR/*
  do
    \rm -f $(basename $f)
    ln -s $f .
  done
  
  ln -s arp/$GRID/ICMSHFCSTINIT
  
  cp arp/fort.4 .
  chmod 644 fort.4
  
  # Set the number of nodes, tasks, threads for the model
  
  NNODE_FC=$SLURM_NNODES
  NTASK_FC=4
  NOPMP_FC=2
  
  # Set the number of nodes, tasks, threads for the IO server
  
  NNODE_IO=0
  NTASK_IO=8
  NOPMP_IO=4
  
  let "NPROC_FC=$NNODE_FC*$NTASK_FC"
  let "NPROC_IO=$NNODE_IO*$NTASK_IO"
  
  # Set forecast term; reduce it for debugging
  
  STOP=12
  
  # Modify namelist
  
  xpnam --delta="
  &NAMRIP
    CSTOP='h$STOP',
  /
  " --inplace fort.4
  
  xpnam --delta="
  &NAMIO_SERV
    NPROC_IO=$NPROC_IO,
  /
  &NAMPAR0
    NPROC=$NPROC_FC,
    $(square $NPROC_FC)
  /
  &NAMPAR1
    NSTRIN=$NPROC_FC,
  /
  " --inplace fort.4
  
  # Change NPROMA
  
  xpnam --delta="
  &NAMDIM
    NPROMA=-32,
  /
  " --inplace fort.4
  
  # Disable output
  
  xpnam --delta="
  &NAMCT1
    N1HIS=0,
  /
  " --inplace fort.4
  
  ls -lrt
  
  cat fort.4
  
  ${method}_setup $PACK
  
  BIN=$PACK/bin/MASTERODB
  
  grib_api_setup $BIN
  
  # Run the model; use your mpirun
  
  export MPIAUTOCONFIG=mpiauto.PGI.conf
  openacc-bind --nn $NNODE_FC --nnp $NTASK_FC ; cat openacc_bind.txt
  /opt/softs/mpiauto/mpiauto \
   --verbose --wrap --wrap-stdeo --nouse-slurm-mpi \
      --nnp $NTASK_FC --nn $NNODE_FC --openmp $NOPMP_FC -- $BIN \
   -- --nnp $NTASK_IO --nn $NNODE_IO --openmp $NOPMP_IO -- $BIN 
  
  ls -lrt

)

done

for method in openmp openmpsinglecolumn openaccsinglecolumn
do
  echo "==> $method <=="
  diffNODE nominal/NODE.001_01 $method/NODE.001_01
done

/opt/softs/adm/slurm/bin/ja


