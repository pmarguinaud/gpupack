
Compile & validate ARPEGE with physics on NVIDIA accelerators.

This repository contains :

- a frozen version of gmkpack (in the gmkpack directory)
- configuration files for gmkpack (in the support directory)
- test cases at various resolutions for ARPEGE (cy49 directory), with references
- scripts to run the test cases (scripts/sbatch-meteo.sh & scripts/sbatch-ecmwf.sh)
- scripts to compile ancillary libraries (hdf, netcdf, eccodes, lapack, eigen3, dummies for other unused libraries)
- scripts to prepare & compile packs with different compilers

# Fetch gpupack

Install gpupack in your HOME directory :

```
$ cd $HOME
$ git clone https://github.com/pmarguinaud/gpupack.git
```

It is possible to clone gpupack somewhere else, but in this case, you need to create a symbolic link in your HOME
to point to the right location of gpupack :

```
cd $SCRATCH
$ git clone https://github.com/pmarguinaud/gpupack.git
$ cd $HOME
$ ln -s $SCRATCH/gpupack
```

Then cd to `$HOME/gpupack`, and inspect the content of the script `gpupack` :

```
export GPUPACK_PREFIX=$HOME/gpupack

cd $GPUPACK_PREFIX

# Load gpupack shell functions

. $GPUPACK_PREFIX/scripts/gpupack

# Create gpupack profile

create_gpupack_sh

# Load gpupack profile

. ./gpupack.sh

# Install common libraries (architecture independent)

common_install

# Choose a compiler

ARCH=INTEL1805

# Install architecture dependent libraries

libraries_install  

# Pick a cycle & a branch

CYCLE=49t0
BRANCH=compile_with_pgi_2303-field_api
REPO=https://github.com/pmarguinaud/IAL.git

# Choose architecture flavor

OPT=2d

# Create the pack

pack_create 

# Compile the pack

pack_compile

```

Each step is detailled in the following sections.

# Create gpupack profile

The shell function `create_gpupack_sh` will create gpupack.sh. You will have to manually source this file
before working with gpupack

# Install ancillary libraries

## Architectire independant utilities

Perl version 5.26 has a bug; it is therefore required to install a more recent version. gpupack is shipped with 
the source code of Perl 5.38. 

fypp a Fortran pre-processor is mandatory to compile ARPEGE source code. gpupack can fetch and install fypp.

A recent version of cmake is required to compile ARPEGE libraries. gpupack can install cmake 3.26.



