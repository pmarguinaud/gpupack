#!/bin/bash
#SBATCH --export=GPUPACK_PREFIX
#SBATCH --job-name=arp
#SBATCH --nodes=1
#SBATCH --time=00:45:00
#SBATCH --exclusive
#SBATCH --verbose
#SBATCH --no-requeue
#SBATCH -p ndl
#SBATCH --switches=3

set -x
set -e

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

cat /proc/cpuinfo

if [ -f /usr/bin/nvidia-smi ]
then
/usr/bin/nvidia-smi
fi


export PATH=$GPUPACK_PREFIX/scripts:$PATH

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

PACK=$1
GRID=$2

ARCH=$(perl -e ' use File::Basename; my $pack = shift; $pack = &basename ($pack); $pack =~ m/\.(\w+)\.(\w+)$/o; print $1 ' $PACK)
OPT=$(perl -e ' use File::Basename; my $pack = shift; $pack = &basename ($pack); $pack =~ m/\.(\w+)\.(\w+)$/o; print $2 ' $PACK)

export PACK
export GRID
export DATADIR=$GPUPACK_PREFIX/cy49

for method in nominal openmp openmpsinglecolumn openaccsinglecolumn
do
  mkdir -p $method
  cd $method
  
  for f in $DATADIR/*
  do
    \rm -f $(basename $f)
    ln -s $f .
  done
  
  cat arp/$GRID/ICMSHFCSTINIT.* > ICMSHFCSTINIT
  
  cp arp/fort.4 .
  chmod 644 fort.4
  
  # Set the number of nodes, tasks, threads for the model
  
  NNODE_FC=$SLURM_NNODES
  NTASK_FC=4
  NOPMP_FC=32
  
  # Set the number of nodes, tasks, threads for the IO server
  
  NNODE_IO=0
  NTASK_IO=8
  NOPMP_IO=4
  
  set +e
  let "NPROC_FC=$NNODE_FC*$NTASK_FC"
  let "NPROC_IO=$NNODE_IO*$NTASK_IO"
  set -e
  
  # Set forecast term; reduce it for debugging
  
  STOP=6
  
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

  ref="$GPUPACK_PREFIX/cy49/arp/$GRID/ref/$ARCH.$OPT/$method/NODE.001_01"
  if [ ! -f "$ref" ]
  then
    dir=$(dirname $ref)
    mkdir -p $dir
    cp drhook.prof.1 $dir/drhook.prof.1
    cp NODE.001_01 $dir/NODE.001_01
  else
    diffNODE $ref NODE.001_01
  fi

  cd ..

done

for method in openmp openmpsinglecolumn openaccsinglecolumn
do
  echo "==> openmp - $method <=="
  diffNODE nominal/NODE.001_01 $method/NODE.001_01
done

echo "==> openmpsinglecolumn - openaccsinglecolumn <=="
diffNODE openmpsinglecolumn/NODE.001_01 openaccsinglecolumn/NODE.001_01

/opt/softs/adm/slurm/bin/ja


