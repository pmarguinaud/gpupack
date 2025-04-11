package AMDRA;

use strict;
use FindBin qw ($Bin);
use base qw (Exporter);

our @EXPORT = qw (&fixEnv &prefix &site &fixLink $AMDRA_PREFIX $OMPI_PREFIX);

our $AMDRA_PREFIX="/home/marguina/install/rocm-afar-7450-drop-6.0.0";

our $OMPI_PREFIX = "openmpi-5.0.7";

sub fixEnv
{
  my @u = qw (CC CXX F77 F90 FC I_MPI_CC I_MPI_CXX I_MPI_F90 I_MPI_FC OMPI_CC OMPI_CXX OMPI_FC);
  delete $ENV{$_} for (@u);
  $ENV{LD_LIBRARY_PATH} = "$AMDRA_PREFIX/lib";
  $ENV{PATH} = "$AMDRA_PREFIX/bin:$ENV{PATH}";
}

sub prefix
{
  use Sys::Hostname;
  my $host  = &hostname ();
  return $AMDRA_PREFIX;
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
}

1;
