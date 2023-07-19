
Compile & validate ARPEGE with physics on NVIDIA accelerators.

This repository contains :

- a frozen version of gmkpack (in the gmkpack directory)
- configuration files for gmkpack (in the support directory)
- test cases at various resolutions for ARPEGE (cy49 directory), with references
- scripts to run the test cases (scripts/sbatch-meteo.sh & scripts/sbatch-ecmwf.sh)
- scripts to compile ancillary libraries (hdf, netcdf, eccodes, lapack, eigen3, dummies for other unused libraries)
- scripts to prepare & compile packs with different compilers

# Requirements

Compilers :

- nvhpc/23.03 or nvhpc/23.5
- Intel 18.05
- Any other C/C++/FORTRAN with MPI support

Python 3

At least 100Gb of free disk space.

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

Each step is detailled in the following sections. When you have understood these different steps, you 
will be able to combine them to automate building and testing in your own script, taking into account
the constraints if your environment.

# Create gpupack profile

The shell function `create_gpupack_sh` will create gpupack.sh. You will have to manually source this file
before working with gpupack

# Install common ancillary libraries & utilities

These are architecture independant libraries.

Perl version 5.26 has a bug; it is therefore required to install a more recent version. gpupack is shipped with 
the source code of Perl 5.38. 

fypp a Fortran pre-processor is mandatory to compile ARPEGE source code. gpupack can fetch and install fypp.

A recent version of cmake is required to compile ARPEGE libraries. gpupack can install cmake 3.26.

The yaml Python module can also be installed by gpupack.

Please look at scripts/gpupack.common and see how to adapt it to your environment.

# Install architecture dependent libraries

Before doing that, you need to setup wrappers for your compiler suite. Please look in the support/wrap/ directory and 
see if one existing architecture (let us call it ARCH) fits your needs. If so, please edit the scripts in 
support/wrap/ARCH, so that these scripts can compile actual code (you will probably need to fix some paths which are
different on your system), ** with all library references resolved by the linker ** (that is, do not forger to add 
`-Wl,-rpath,/path/to/libraries` as needed).




