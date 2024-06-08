package NVHPC;

use strict;
use FindBin qw ($Bin);
use base qw (Exporter);

our @EXPORT = qw ($NVHPC_ROOT $NVHPC_CUDA_HOME $OMPI_PREFIX $CUDA_PREFIX &fixEnv &prefix &site &fixLink $CUDA_VERSION $NVHPC_ARCH);

my ($version, $cuda, $hpcx) = ('24.5', '12.4', '2.19');
our $NVHPC_ROOT = &prefix () . '/hpc_sdk/Linux_x86_64/' . $version;

our $OMPI_PREFIX = "comm_libs/$cuda/hpcx/hpcx-$hpcx/ompi";
our $CUDA_PREFIX= "cuda/$cuda";
our $NVHPC_CUDA_HOME = "$NVHPC_ROOT/$CUDA_PREFIX";
our $CUDA_VERSION = $cuda;
our $NVHPC_ARCH = 'x86_64-linux';

sub fixEnv
{
  my @u = qw (CC CXX F77 F90 FC I_MPI_CC I_MPI_CXX I_MPI_F90 I_MPI_FC OMPI_CC OMPI_CXX OMPI_FC);
  delete $ENV{$_} for (@u);

  $ENV{LD_LIBRARY_PATH} = "$NVHPC_ROOT/comm_libs/nvshmem/lib:$NVHPC_ROOT/comm_libs/nccl/lib:$NVHPC_ROOT/$OMPI_PREFIX/lib:$NVHPC_ROOT/math_libs/lib64:$NVHPC_ROOT/compilers/lib:$NVHPC_ROOT/cuda/lib64";
  $ENV{PATH} = "$NVHPC_ROOT/compilers/bin:$ENV{PATH}";
  $ENV{CPATH} = "$NVHPC_ROOT/$OMPI_PREFIX/include" . ($ENV{CPATH} ? ':' . $ENV{CPATH} : '');
  $ENV{NVHPC_CUDA_HOME} = "$NVHPC_ROOT/$CUDA_PREFIX";
}

sub prefix
{
  use Sys::Hostname;
  my $host  = &hostname ();
  return '/ec/res4/hpcperm/sor/install/nvidia' if ($host =~ m/^ac\d+-\d+\.bullx$/o);
  return '/opt/softs/gcc/9.2.0' if ($host =~ m/^(?:belenos|taranis)/o);
  die ("Unexpected host : $host");
}

sub site
{
  use Sys::Hostname;
  my $host  = &hostname ();

  for ($host)
    {
      return 'meteo' if (m/^(?:belenos|taranis)/o);
      return 'ecmwf' if (m/^ac\d+-\d+\.bullx$/o);
    }

  die;
}

sub fixLink
{

  for (@_)
    {
      s/^-l\[(\d+)\]/-l_${1}_/go;
    }

  for my $f (<*.a>)
    {
      if ((my $g = $f) =~ s/^lib\[(\d+)\]\.a$/lib_${1}_.a/o)
        {
          link ($f, $g);
        }
    }

}

1;
