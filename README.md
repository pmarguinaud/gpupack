
Compile, run & validate ARPEGE with physics on NVIDIA accelerators.

This repository contains :

- a frozen version of gmkpack (in the gmkpack directory)
- configuration files for gmkpack (in the support directory)
- source code for various ancillary libraries
- scripts to compile ancillary libraries (hdf, netcdf, eccodes, lapack, eigen3, dummies for other unused libraries)
- scripts to prepare & compile packs with different compilers
- test cases at various resolutions for ARPEGE (`cy49` directory), with references
- sample scripts to run the test cases (`scripts/sbatch-meteo.sh` & `scripts/sbatch-ecmwf.sh`)

# Requirements

Compilers :

- NVHPC 23.11, 24.1, 24.3, 24.5
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

# Options of gpupack

gpupack accepts the following options (some of them similar to those used by gmkpack) :

* -r; $RELEASE
* -b; $BRANCH
* -l; $ARCH, architecture/compiler name
* -o; $OPT, architecture/compiler flavor
* -R; git $REPOSITORY
* -G; use ectrans GPU library
* -N; create the pack, but do not compile
* -S; do everything in a screen session
* -H; display help message and exit

gpupack will **fetch** a branch named `${RELEASE}_${BRANCH}` in the git $REPOSITORY given by the -R option, and **create**
a pack named `${RELEASE}_${BRANCH}.01.${ARCH}.${OPT}`.

# Compiling & testing with gpupack

cd to `$HOME/gpupack`, and inspect the content of the scripts `gpupack` and `scripts/gpupack`:

```

export GPUPACK_PREFIX=$HOME/gpupack

# Cycle & a branch

export CYCLE=49t2
export BRANCH=openacc
export REPO=https://github.com/pmarguinaud/IAL.git
export ECTRANS_GPU=OFF

# Architecture flavor

export OPT=1d 

# Compiler

export ARCH=NVHPC2403

...

# Load gpupack shell functions

  source $GPUPACK_PREFIX/scripts/gpupack

# Create gpupack profile

  create_gpupack_sh

# Load gpupack profile
  
  source ./gpupack.sh

# Install common libraries (architecture independent)

  if [ ! -d "$GPUPACK_PREFIX/install/common" ]
  then
    common_install
  fi

# Check versions of Perl & cmake

  common_check_versions

# Install architecture dependent libraries

  if [ ! -d "$GPUPACK_PREFIX/install/$ARCH" ]
  then
    libraries_install
  fi  

# Create a pack

  pack_create 

# Compile the pack

  if [ "$COMPILE" == "ON" ]
  then
    pack_compile
  fi  

```

Each step is detailed in the following sections. When you have understood these different steps, you 
will be able to combine them to automate building and testing in your own script, taking into account
the constraints of your environment.

# Create gpupack profile

The shell function `create_gpupack_sh` (from `scripts/gpupack`) will create gpupack.sh. You will have to manually source this file
before working with gpupack.

# Install common ancillary libraries & utilities

These are architecture independant libraries.

- Perl version 5.26 has a bug which affects strongly the performance of gmkpack; it is therefore required to install a more recent version. 
gpupack is shipped with the source code of Perl 5.38. 

- fypp (a Fortran pre-processor) is mandatory to compile ARPEGE source code. gpupack can fetch and install fypp.

- A recent version of cmake is required to compile ARPEGE libraries. gpupack can install cmake 3.26.

- The yaml Python module can also be installed by gpupack.

- The utilities from the vimpack repository are required (gitpack & vimpack) and are installed by gpupack.

Please look at `scripts/gpupack.common` and see how to adapt it to your environment. 

# Install architecture dependent libraries

Before doing that, you need to setup wrappers for your compiler suite. Please look in the support/wrap/ directory and 
see if one existing architecture (let us call it ARCH) fits your needs. If so, please edit the scripts in 
support/wrap/ARCH, so that these scripts can compile actual code (you will probably need to fix some paths which are
different on your system), **with all library references resolved by the linker** (that is, do not forget to add 
`-Wl,-rpath,/path/to/libraries` as needed, so that references to dynamic libraries be resolved using RPATH).

If your architecture does not exist, then try to pick something similar from what already exists, and make a copy, 
in a different directory. Then edit the compiler wrappers.

# Install architecture dependent libraries

gpupack is shipped with the following libraries, and can install them :

- eccodes
- hdf5
- netcdf
- netcdf/fortran
- lapack
- eigen
- cutlass (only compiled when the nvhpc compiler suite is used)

It can also create dummies for these libraries (which are not required to make an ARPEGE forecast) :

- rgb
- bufr
- gribex
- fdbdummy
- wamdummy
- naglitedummy
- oasisdummy
- ibmdummy
- mpidummy

Look at `scripts/gpupack.libraries` and see how to adapt it to fit your needs and your constraints.

# Choose & configure your architecture flavor

Please look at the content of the support/arch directory. Each architecture (ARCH) might exist with different
flavors (mostly compilation options or floating point precision); for example, INTEL1805 exists with two suffixes :
- 2d : -O2, double precision
- 2s : -O2, single precision

Look at the contents of INTEL1805.2d for instance. If your architecture does not exist, you need to 
copy INTEL1805.2d into ARCH.OPT, and adapt the contents of ARCH.OPT.

Please note that the NVIDIA target architecture has to be selected in NVHPC2401.1d and NVHPC2401.1s (GPU = cc70 or GPU = cc80).

# Create a pack 

The `pack_create` function (defined in `scripts/gpupack.pack`) creates a pack; this involves the following
steps :
- invoking `gmkpack` with the appropriate options
- download source code, for ARPEGE and other differents components (ecbuild, eckit, oops, fiat, ectrans, field_api)

The pack will be created in pack. Its name is `${CYCLE}_${BRANCH}.01.${ARCH}.${OPT}`. It should contain the following scripts :
- `ics_packages`; for compiling libraries in `hub/local`
- `ics_masterodb`; for compiling ARPEGE source code
- `ld_masterodb`; does not compile ARPEGE source code, only create ARPEGE executable

# Compile the pack

The `pack_compile` function (defined in `scripts/gpupack.pack`) compiles the pack. This involves :
- compiling the packages (ecbuild, eckit, ...) with `ics_packages`
- compiling the ARPEGE source code with `ics_masterodb`

If the compilation is successful, then unnecessary files may be removed (directory `hub/local/build`), but also 
with `lockpack` in `src/local`.

It is possible to invoke `ics_packages` and `ics_masterodb` manually from
within the pack. Please note that by default `ics_packages` and `ics_masterodb`
will run with 16 threads, but it is possible to change the value by editing
GMK\_THREADS in those files.

If the compilation is successful, then the `bin/MASTERODB` file will exist and be executable.

Please note that compiling the code on ECMWF cluster is not possible on login nodes, because of cgroups limitations; it
is necessary to turn `ics_masterodb` into a batch job and submit it in the `par` queue.

# Run the code

A script and different initial condition files are provided in the `cy49` directory; we provide different resolutions : t0031l15, t0107l70, t0538l60, t0798l90.

The t0031l15 runs in about 20s on an dual socket AMD Rome node. The t0798l90 requires at least three dual socket AMD nodes; it has also been tested on 
three dual socket AMD nodes, each equipped with 4 NVIDIA V100 cards.

Please look at the script `cy49/arp/arp.sh` and see how you can adapt it to your environment. The following scripts :
- `scripts/sbatch-ecmwf.sh`
- `scripts/sbatch-meteo.sh`

provides examples of how `cy49/arp/arp.sh` is submitted to ECMWF & Meteo-France batch systems.

# Matrix multiplications in grid-point calculations

These matrix multiplications occur in the following routines :
- `verint.F90`
- `verints.F90`
- `verder.F90`

We normally use DGEMM (from the MKL library) in these routines, but we cannot use DGEMM on accelerators, we coded some simple
multiplications that we enable with the LLSIMPLE_DGEMM library.

# OpenMP & OpenACC

The script `cy49/arp/arp.sh` run the code in four different modes :
- nominal : ARPEGE physics is managed by a very large OpenMP section; this is the optimal mode on traditionnal CPUs.
- openmp : ARPEGE physics is managed by a succession of small OpenMP sections
- openmpsinglecolumn : ARPEGE physics is managed by a succession of small OpenMP sections, **without vectorisation** with 
column processed independently.  This is meant for validation.
- openaccsinglecolumn : ARPEGE physics is managed by a succession of small OpenACC sections (with possibly a few OpenMP
section in between). This is supposed to be the optimal mode on GPUs.

Some comparison are made when references are available (in `cy49/arp/*/ref` directories). We also make the following
comparisons : 

- nominal - openmp
- nominal - openmpsinglecolumn
- nominal - openaccsinglecolumn
- openmpsinglecolumn - openaccsinglecolumn

We consider that these comparison should lead to identical results in the following cases :

- INTEL **with vectorisation** :

```
+---------------------+----------+---------+---------------------+-----------------------+
|                     |  nominal |  openmp |  openmpsinglecolumn |  openaccsinglecolumn  |
+---------------------+----------+---------+---------------------+-----------------------+
| nominal             |    =     |    =    |                     |                       |
+---------------------+----------+---------+---------------------+-----------------------+
| openmp              |    =     |    =    |                     |                       |
+---------------------+----------+---------+---------------------+-----------------------+
| openmpsinglecolumn  |          |         |          =          |           =           |
+---------------------+----------+---------+---------------------+-----------------------+
| openaccsinglecolumn |          |         |          =          |           =           |
+---------------------+----------+---------+---------------------+-----------------------+
```

- NVHPC **without vectorisation** :

```
+---------------------+----------+---------+---------------------+-----------------------+
|                     |  nominal |  openmp |  openmpsinglecolumn |  openaccsinglecolumn  |
+---------------------+----------+---------+---------------------+-----------------------+
| nominal             |    =     |    =    |          =          |                       |
+---------------------+----------+---------+---------------------+-----------------------+
| openmp              |    =     |    =    |          =          |                       |
+---------------------+----------+---------+---------------------+-----------------------+
| openmpsinglecolumn  |    =     |    =    |          =          |                       |
+---------------------+----------+---------+---------------------+-----------------------+
| openaccsinglecolumn |          |         |                     |           =           |
+---------------------+----------+---------+---------------------+-----------------------+
```


