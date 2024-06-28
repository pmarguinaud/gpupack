#!/bin/bash
#SBATCH --export=GPUPACK_PREFIX
#SBATCH --job-name=arp
#SBATCH --time=03:00:00
#SBATCH --verbose
#SBATCH --no-requeue

set -x
set -e

function ecmwf_mpirun ()
{
  set +x
  if [ "x$NVHPC_ROOT" = "x" ]
  then
    export MODULEPATH=$HPCPERM/install/nvidia/hpc_sdk/modulefiles:$MODULEPATH
    module purge
    module load nvhpc-hpcx/23.5
    source $NVHPC_ROOT/comm_libs/11.8/hpcx/hpcx-2.14/hpcx-mt-init.sh hpcx_load
  fi
  set -x
  export SLURM_EXPORT_ENV=ALL
  ~sor/install/mpiauto/mpiauto --nouse-slurm-mpi $*
}

function meteo_mpirun ()
{
  export MPIAUTOCONFIG=~marguina/.mpiautorc/mpiauto.PGI.conf
  ~marguina/SAVE/mpiauto/mpiauto --nouse-slurm-mpi $*
# /opt/softs/mpiauto/mpiauto --nouse-slurm-mpi $*
# /opt/softs/mpiauto/mpiauto --prefix-command /opt/softs/nvidia/hpc_sdk/Linux_x86_64/23.11/compilers/bin/compute-sanitizer --nouse-slurm-mpi $*
}

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

function clean_stack ()
{
  unset CLSTACKSIZE
  unset CLSTACKSIZE4
  unset CLSTACKSIZE8
}

function setup_stack ()
{
  clean_stack 
  PREC=$(perl -e ' print substr ($ARGV[0], -1, 1) ' $pack)
  if [ "$PREC" = "s" ]
  then
    export CLSTACKSIZE=0
    export CLSTACKSIZE4=70
    export CLSTACKSIZE8=10
  else
    export CLSTACKSIZE=0
    export CLSTACKSIZE4=10
    export CLSTACKSIZE8=70
  fi
}

function nominal_setup ()
{
  pack=$1
  \rm -f lparallelmethod.txt  lsynchost.txt
  export INPART=0
  export PERSISTENT=0
  export PARALLEL=0
  unset LPARALLELMETHOD_VERBOSE
  export SLCOMMACC=0
  export SLEXTPOLACC=0
  clean_stack
  export LLSIMPLE_DGEMM=1
}

function openmp_setup ()
{
  pack=$1
  \rm -f lparallelmethod.txt  lsynchost.txt
  export INPART=1
  export PERSISTENT=1
  export PARALLEL=1
  unset LPARALLELMETHOD_VERBOSE
  export SLCOMMACC=0
  export SLEXTPOLACC=0
  clean_stack 
  export LLSIMPLE_DGEMM=1
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
  export SLCOMMACC=0
  export SLEXTPOLACC=0
  setup_stack $pack
  export LLSIMPLE_DGEMM=1
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
  export SLCOMMACC=1
  export SLEXTPOLACC=1
  setup_stack $pack
  export LLSIMPLE_DGEMM=1
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
set +e
/usr/bin/nvidia-smi
set -e
fi


SITE=$(perl -e '
  use Sys::Hostname;
  my $host  = &hostname ();
  if ($host =~ m/^ac\d+-\d+\.bullx$/o)
    {
      print "ecmwf";
      exit (0);
    }
  elsif ($host =~ m/^(?:belenos|taranis)/o)
    {
      print "meteo";
      exit (0);
    }
  die ("Unexpected host : $host");
')


export PATH=$GPUPACK_PREFIX/scripts:$PATH

# Change to a temporary directory

if [ "x$workdir" != "x" ]
then
  TMPDIR=$workdir/tmp/arp.$SLURM_JOBID
elif [ "x$SCRATCH" != "x" ]
then
  TMPDIR=$SCRATCH/tmp/arp.$SLURM_JOBID
else
  exit
fi

mkdir -p $TMPDIR

cd $TMPDIR

PACK=$1
GRID=$2

if [ "x$PACK" = "x" ]
then
  echo "PACK is not set"
  exit
fi

if [ "x$GRID" = "x" ]
then
  echo "GRID is not set"
  exit
fi

if [ "x$GPUPACK_PREFIX" = "x" ]
then
  echo "GPUPACK_PREFIX is not set"
  exit
fi


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
  
  if [ "$method" = "openmpsinglecolumn" -o "$method" = "openaccsinglecolumn" ]
  then
    ECRADSOLVER='McICA ACC'
    ECRADARCH=GPU
  else
    ECRADSOLVER='McICA'
    ECRADARCH=CPU
  fi

  if [ "$method" = "openaccsinglecolumn" ]
  then
    LECRADACC=.TRUE.
  else
    LECRADACC=.FALSE.
  fi

# NECRADLEN=512 # OK
# NECRADLEN=768 # OK
  NECRADLEN=1024

  xpnam --delta="
  &NAERAD
    LRRTM=.TRUE., 
    LSRTM=.TRUE.,
    LUSEPRE2017RAD=.FALSE.,
    NHINCSOL=0,
    NMCICA=1,
    NOVLP=1,
    NRADFR=-1,
    NRADIP=2,
    NRADLP=2,
    NSW=6,
    RLWINHF=0.9,
    STBKG=0.045,
    TRBKG=0.03,
    CECRADARCH='$ECRADARCH',
    NECRADLEN=$NECRADLEN,
    LECRADACC=$LECRADACC,
  /
  &RADIATION
    DIRECTORY_NAME='.',
    DO_SW=.TRUE.,
    DO_LW=.TRUE.,
    DO_SW_DIRECT=.TRUE.,
    DO_CLEAR=.TRUE.,
    USE_GENERAL_CLOUD_OPTICS=.FALSE.,
    USE_GENERAL_AEROSOL_OPTICS=.FALSE.,
    LIQUID_MODEL_NAME='SOCRATES',
    ICE_MODEL_NAME='Fu-IFS',
    SW_SOLVER_NAME='$ECRADSOLVER',
    LW_SOLVER_NAME='$ECRADSOLVER',
    OVERLAP_SCHEME_NAME='Exp-Ran',
    CLOUD_FRACTION_THRESHOLD=0.000001,
    DO_LW_AEROSOL_SCATTERING=.FALSE.,
    DO_LW_CLOUD_SCATTERING=.FALSE.,
    CLOUD_INHOM_DECORR_SCALING=0.5,
    USE_BETA_OVERLAP=.FALSE.,
    USE_VECTORIZABLE_GENERATOR=.FALSE.,
    DO_SAVE_RADIATIVE_PROPERTIES=.FALSE.,
    DO_3D_EFFECTS=.FALSE.,
    SW_ENTRAPMENT_NAME='Explicit',
    IVERBOSE=1,
    IVERBOSESETUP=2,
    USE_AEROSOLS=.TRUE.,
    DO_SAVE_SPECTRAL_FLUX=.FALSE.,
    DO_SAVE_GPOINT_FLUX=.FALSE.,
    DO_LW_DERIVATIVES=.TRUE.,
    GAS_MODEL_NAME='RRTMG-IFS',
    DO_SURFACE_SW_SPECTRAL_FLUX=.TRUE.,
    DO_FU_LW_ICE_OPTICS_BUG=.FALSE.,
    DO_SW_DELTA_SCALING_WITH_GASES=.TRUE.,
    DO_CANOPY_FLUXES_LW=.TRUE.,
    DO_CANOPY_FLUXES_SW=.TRUE.,
    DO_NEAREST_SPECTRAL_SW_ALBEDO=.FALSE.,
    SW_ALBEDO_WAVELENGTH_BOUND(1:5)=2.5D-7,4.4D-7,6.9D-7,0.00000119,0.00000238,
    I_SW_ALBEDO_INDEX(1:6)=1,2,3,4,5,6,
    DO_NEAREST_SPECTRAL_LW_EMISS=.TRUE.,
    LW_EMISS_WAVELENGTH_BOUND(1:2)=0.000008,0.000013,
    I_LW_EMISS_INDEX(1:3)=1,2,1,
    DO_WEIGHTED_SURFACE_MAPPING=.FALSE.,
    N_AEROSOL_TYPES=6,
  /
  " --inplace fort.4

  ls -lrt
  
  cat fort.4
  
  ${method}_setup $PACK

  BIN=$PACK/bin/MASTERODB
  
  grib_api_setup $BIN
  
  # Run the model
  
  openacc-bind --nn $NNODE_FC --nnp $NTASK_FC --np $NPROC_FC ; cat openacc_bind.txt

  ${SITE}_mpirun \
   --verbose --wrap --wrap-stdeo \
      --nnp $NTASK_FC --nn $NNODE_FC --openmp $NOPMP_FC -- $BIN \
   -- --nnp $NTASK_IO --nn $NNODE_IO --openmp $NOPMP_IO -- $BIN 

  if [ "x$SITE" = "x" ]
  then
    echo "Use your own mpirun"
    exit
  fi
 
  
  ls -lrt


  pack=$(basename $PACK)
  ref="$GPUPACK_PREFIX/cy49/arp/$GRID/ref/$pack/$method/NODE.001_01"
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
  echo "==> nominal - $method <=="
  diffNODE nominal/NODE.001_01 $method/NODE.001_01
done

echo "==> openmpsinglecolumn - openaccsinglecolumn <=="
diffNODE openmpsinglecolumn/NODE.001_01 openaccsinglecolumn/NODE.001_01

/opt/softs/adm/slurm/bin/ja


