package NVHPC;

use strict;
use FindBin qw ($Bin);
use base qw (Exporter);

our @EXPORT = qw ($NVHPC_ROOT $OMPI_PREFIX $CUDA_PREFIX &fixEnv &prefix &site &fixLink);

our $NVHPC_ROOT = &prefix () . '/nvidia/hpc_sdk/Linux_x86_64/' . &version ();
our $OMPI_PREFIX = "comm_libs/11.8/hpcx/hpcx-2.14/ompi";
our $CUDA_PREFIX= "cuda/11.8";

sub version
{
  use File::Basename;
  use File::Spec;
  use Cwd;
 
  my $program = 'File::Spec'->rel2abs ($0);
  my $version = &basename (&dirname ($program));

  my ($yy, $mm) = ($version =~ m/^NVHPC(\d\d)(\d\d)$/o);
  $mm =~ s/^0//o;
  $version = "$yy.$mm";
  return $version;
}

sub fixEnv
{
  my @u = qw (CC CXX F77 F90 FC I_MPI_CC I_MPI_CXX I_MPI_F90 I_MPI_FC OMPI_CC OMPI_CXX OMPI_FC);
  delete $ENV{$_} for (@u);

  $ENV{LD_LIBRARY_PATH} = "$NVHPC_ROOT/comm_libs/nvshmem/lib:$NVHPC_ROOT/comm_libs/nccl/lib:$NVHPC_ROOT/$OMPI_PREFIX/lib:$NVHPC_ROOT/math_libs/lib64:$NVHPC_ROOT/compilers/lib:$NVHPC_ROOT/cuda/lib64";
  $ENV{PATH} = "$NVHPC_ROOT/compilers/bin:$ENV{PATH}";
  $ENV{NVHPC_CUDA_HOME} = "$NVHPC_ROOT/$CUDA_PREFIX";

  if (&site () eq 'meteo')
    {
      # Hack for bug in math lib of NVHPC 23.11, provided by Louis Stuber (NVIDIA)
      $ENV{CPATH} = "$Bin/pgi-math-wrapper/";
    }

}

sub prefix
{
  use Sys::Hostname;
  my $host  = &hostname ();
  return '/ec/res4/hpcperm/sor/install' if ($host =~ m/^ac\d+-\d+\.bullx$/o);
  return '/opt/softs' if ($host =~ m/^(?:belenos|taranis)/o);
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
