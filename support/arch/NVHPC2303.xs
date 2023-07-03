
# ARCHITECTURE FILE FOR LINUX PLATFORMS WITH NVHPC COMPILER AND OPENMPI
# =====================================================================

ARCH = NVHPC2303

# Fortran (cross-)compiler
# ------------------------

FRTNAME = $HOME/gpupack/support/wrap/$ARCH/mpif90

# C (cross-)compiler
# ------------------

VCCNAME = $HOME/gpupack/support/wrap/$ARCH/mpicc

# C++ (cross-)compiler
# ------------------

CXXNAME = $HOME/gpupack/support/wrap/$ARCH/mpicxx

# Native C compiler
# -----------------

CCNATIVE = $HOME/gpupack/support/wrap/$ARCH/mpicc

# Native C linker flags
# ---------------------

LNK_MPCCNATIVE =

# fypp preprocessor
# -----------------

GMK_FYPP = fypp

# fypp preprocessor background flags
# ----------------------------------

GMK_FYPP_FLAGS = -m os -m yaml

# Fortran compiler default version (stamp)
# ----------------------------------------

LIBFRT = echo NVHPC2303

# Basic compilation flags
# -----------------------

FRTFLAGS = -c -mp -fPIC -Minfo -gopt -Mlarge_arrays -Mlist -traceback -Mnofma -Mbyteswapio -Mbackslash -Mstack_arrays
VCCFLAGS = -c -mp -fPIC -Minfo -gopt -Mlarge_arrays -Mlist -traceback -Mnofma
# Option -C in order to create files without compiling inside odb98
# In order to have any effect from the following -1 or -A options,
# -O3 optimization level must be activated.
ODBFLAGS = -C -O3

# Fortran double precision flags
# ------------------------------
DBL_FRTFLAGS = 

# Fortran Cpp + extensions flags
# ------------------------------
F77_CPPFLAG =
F90_CPPFLAG = 
F77_NOCPPFLAG =
F90_NOCPPFLAG = 

# Fortran format flag
# --------------------
FREE_FRTFLAG = 
FIXED_FRTFLAG = 

# Optimized compilation flag
# --------------------------

OPT_FRTFLAGS = -acc=gpu -O1 -gopt -gpu=cc70 -Minfo=accel,all,intensity,ccff
OPT_VCCFLAGS = -acc=gpu -O0 -gopt -gpu=cc70 -Minfo=accel,all,intensity,ccff

# Debugging compilation flag
# --------------------------

DBG_FRTFLAGS = -g -O0

# Bound checking compilation flag
# -------------------------------

BCD_FRTFLAGS = -Mbounds

# NaN pre-initialisation flag
# ---------------------------

NAN_FRTFLAGS = 

# Listing compilation flag
# ------------------------

LIST_FRTFLAGS = 
LIST_VCCFLAGS =

# Filename extension for listing
# ------------------------------

LIST_EXTENSION = list

# Additive compilation flags
# --------------------------

MACROS_FRT = -DLINUX -DLITTLE_ENDIAN -DLITTLE -DADDRESS64 -DGRIB_API_1 -DPARKIND1_SINGLE
MACROS_CC = -DLINUX -DLITTLE_ENDIAN -DLITTLE -DGRIB_API_1 -DPARKIND1_SINGLE
MACROS_CXX = -std=c++11
MACROS_BL95 = -DLINUX -DLITTLE_ENDIAN -DLITTLE -DIS_MAIN_PROG -DSTATIC_LINKING
MACROS_ODB98 = -DLINUX -DLITTLE_ENDIAN -DLITTLE -DXPRIVATE=PRIVATE -UINTERCEPT_ALLOC -UUSE_ALLOCA_H -DWITHOUT_OML


GMK_FCFLAGS_SATRAD = -D_RTTOV_DO_DISTRIBCOEF -D_RTTOV_HDF -DWITHOUT_EMOSLIB

GMK_FCFLAGS_SURFEX = -Din_surfex -DSFX_ARO -DSFX_ASC -DSFX_OL -DSFX_TXT -DSFX_FA -DSFX_LFI -DARO -DOL -DASC -DTXT -DFA -DLFI
GMK_FCFLAGS_MSE = -DSFX_FA
GMK_FCFLAGS_MPA = 
GMK_FCFLAGS_PHYEX = 

GMK_FCFLAGS_IFSAUX = -DHIGHRES -DBLAS
GMK_FCFLAGS_ALGOR = -DBLAS
GMK_CFLAGS_IFSAUX = -DPOINTER_64 -DWITHOUT_CXXDEMANGLE
GMK_CFLAGS_ODB = -DSTATIC_LINKING -DXPRIVATE=PRIVATE -DINTERCEPT_ALLOC -DUSE_ALLOCA_H -DCANARI -DHAS_LAPACK -DNO_CURSES -DODB_NMXUPD=4
GMK_CFLAGS_BLACKLIST = -DSTATIC_LINKING -DXPRIVATE=PRIVATE -DINTERCEPT_ALLOC -DUSE_ALLOCA_H

GMK_FCFLAGS_TRANS = 
GMK_FCFLAGS_ETRANS = 

# Fortran (cross-)linker
# ----------------------

LNK_STD = $HOME/gpupack/support/wrap/$ARCH/f90

# Message Passing Fortran (cross-)linker
# --------------------------------------

LNK_MPI = $HOME/gpupack/support/wrap/$ARCH/mpif90

# Cc (cross-)linker
# -----------------

LNK_CC = $HOME/gpupack/support/wrap/$ARCH/cc -lrt -lstdc++

# Fortran linking flags
# ----------------------

LNK_FLAGS = -acc=gpu -O1 -gopt -gpu=cc70 -v -lrt -lstdc++ -Wl,-rpath,/home/gmap/mrpm/marguina/gpupack/install/$ARCH/lib64 -Wl,-rpath,/home/gmap/mrpm/marguina/gpupack/install/$ARCH/lib

# Additional linking flags to LNK_FLAGS for c++ executable
# --------------------------------------------------------

LNK_CXX_FLAGS = 

# flags for executable targets
# ----------------------------

LNK_EXEC =

# flags for shared object targets
# -------------------------------

LNK_SOLIB = -shared -o a.out

# Fortran Flag for start/end group libraries
# ------------------------------------------

LNK_STARTG = -Wl,--start-group
LNK_ENDG   = -Wl,--end-group

# Flag for linking with whole static libraries
# ---------------------------------  ---------

LNK_WHOLE_ARCHIVE = -Wl,-whole-archive
LNK_NO_WHOLE_ARCHIVE = -Wl,-no-whole-archive

# Flags for static/dynamic linking
# --------------------------------

LNK_STATIC = -Wl,-Bstatic
LNK_DYNAMIC = -Wl,-Bdynamic

# Load map flag
# -------------

LNK_MAP = -Wl,-M

# Hub
# ---
# Hub general directory
GMK_HUB_DIR      = hub
# Hub general installation directory (must be at a fixed place inside the pack in order to be propagated)
GMK_HUB_INSTALL  = install
# Hub general build directory (absolute path because it may be a non-permanent directory in production mode) :
GMK_HUB_BUILD    = \${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMKLOCAL}/build

# List of projects in hub (ordered sort to enable dependencies)
GMK_HUB_PROJECTS = ecSDK OOPS Atlas Fiat Ectrans FieldAPI

GMK_HUB_LIBRARIES_IN_ecSDK = ecbuild eckit fckit
GMK_HUB_METHOD_FOR_ecSDK = cmake

GMK_HUB_LIBRARIES_IN_OOPS = oops_src
GMK_HUB_METHOD_FOR_OOPS = cmake

GMK_HUB_LIBRARIES_IN_Atlas = atlas
GMK_HUB_METHOD_FOR_Atlas = cmake

GMK_HUB_LIBRARIES_IN_Fiat = fiat
GMK_HUB_METHOD_FOR_Fiat = cmake

GMK_HUB_LIBRARIES_IN_Ectrans = ectrans
GMK_HUB_METHOD_FOR_Ectrans = cmake

GMK_HUB_LIBRARIES_IN_FieldAPI = field_api
GMK_HUB_METHOD_FOR_FieldAPI = cmake


GMK_CMAKE_ecbuild = -Wno-deprecated -Wno-dev -DCMAKE_C_COMPILER=\${VCCNAME}

GMK_CMAKE_eckit = -Wno-deprecated -Wno-dev -DCMAKE_C_COMPILER=\${VCCNAME} -DCMAKE_C_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS}\" -DCMAKE_CXX_COMPILER=\${CXXNAME} -DCMAKE_CXX_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS} ${MACROS_CXX}\" -DCMAKE_BUILD_TYPE=NONE -DENABLE_ECKIT_CMD=OFF -DENABLE_ECKIT_SQL=OFF -DENABLE_BZIP2=OFF -DENABLE_SNAPPY=OFF -DENABLE_LAPACK=OFF -DENABLE_CURL=OFF -DENABLE_DOCS=OFF -DENABLE_SSL=OFF -DBUILD_SHARED_LIBS=BOTH -DECBUILD_2_COMPAT=ON -DECBUILD_2_COMPAT_DEPRECATE=OFF

GMK_CMAKE_fckit = -Wno-deprecated -Wno-dev -DCMAKE_CXX_COMPILER=\${CXXNAME} -DCMAKE_CXX_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS} ${MACROS_CXX}\" -DCMAKE_Fortran_COMPILER=\${FRTNAME} -DCMAKE_BUILD_TYPE=NONE -DCMAKE_PREFIX_PATH=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMK_HUB_INSTALL}/ecSDK -DENABLE_FINAL=OFF -DENABLE_TESTS=OFF -DBUILD_SHARED_LIBS=OFF -DECBUILD_2_COMPAT=ON -DECBUILD_2_COMPAT_DEPRECATE=OFF -DCMAKE_Fortran_FLAGS=\"${FRTFLAGS} -g -O1\"

GMK_CMAKE_oops_src = -Wno-deprecated -Wno-dev -DCMAKE_C_COMPILER=\${VCCNAME} -DCMAKE_C_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS}\" -DCMAKE_CXX_COMPILER=\${CXXNAME} -DCMAKE_CXX_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS} ${MACROS_CXX}\" -DCMAKE_Fortran_COMPILER=\${FRTNAME} -DCMAKE_BUILD_TYPE=NONE -DCMAKE_MODULE_PATH=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMKLOCAL}/\${GMKSRC}/ecSDK/ecbuild/cmake -DECKIT_PATH=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMK_HUB_INSTALL}/ecSDK -DFCKIT_PATH=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMK_HUB_INSTALL}/ecSDK -DENABLE_TESTS=ON -DBUILD_SHARED_LIBS=BOTH -DECBUILD_2_COMPAT=ON -DECBUILD_2_COMPAT_DEPRECATE=OFF -DEIGEN3_INCLUDE_DIR=$HOME/gpupack/install/$ARCH/include/eigen3 -Decbuild_ROOT=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMKSRC}/ecSDK -DCMAKE_Fortran_FLAGS=\"${FRTFLAGS} -g -O1\"

GMK_CMAKE_atlas = -Wno-deprecated -Wno-dev -DCMAKE_C_COMPILER=\${VCCNAME} -DCMAKE_C_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS}\" -DCMAKE_CXX_COMPILER=\${CXXNAME} -DCMAKE_CXX_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS} ${MACROS_CXX}\" -DCMAKE_Fortran_COMPILER=\${FRTNAME} -DCMAKE_BUILD_TYPE=NONE -Decbuild_ROOT=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMKSRC}/ecSDK -DCMAKE_PREFIX_PATH=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMK_HUB_INSTALL}/ecSDK -DENABLE_TESTS=OFF -DBUILD_SHARED_LIBS=OFF -DECBUILD_2_COMPAT=ON -DECBUILD_2_COMPAT_DEPRECATE=OFF -DATLAS_Fortran_FLAGS=\"${FRTFLAGS} -g -O1\"

GMK_CMAKE_fiat = -Wno-deprecated -Wno-dev -DCMAKE_C_COMPILER=\${VCCNAME} -DCMAKE_C_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS}\" -DCMAKE_CXX_COMPILER=\${CXXNAME} -DCMAKE_CXX_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS} ${MACROS_CXX}\" -DCMAKE_Fortran_COMPILER=\${FRTNAME} -DCMAKE_BUILD_TYPE=NONE -Decbuild_ROOT=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMKSRC}/ecSDK -DBUILD_SHARED_LIBS=BOTH -DENABLE_TESTS=OFF -DECBUILD_2_COMPAT=ON -DECBUILD_2_COMPAT_DEPRECATE=OFF -DENABLE_SINGLE_PRECISION=ON -DENABLE_DOUBLE_PRECISION=OFF -DCMAKE_Fortran_FLAGS=\"${FRTFLAGS} -g -O1 -DADDRESS64\"

GMK_CMAKE_ectrans = -Wno-deprecated -Wno-dev -DCMAKE_C_COMPILER=\${VCCNAME} -DCMAKE_C_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS}\" -DCMAKE_CXX_COMPILER=\${CXXNAME} -DCMAKE_CXX_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS} ${MACROS_CXX}\" -DCMAKE_Fortran_COMPILER=\${FRTNAME} -DCMAKE_BUILD_TYPE=NONE -Decbuild_ROOT=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMKSRC}/ecSDK -Dfiat_ROOT=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMK_HUB_INSTALL}/Fiat -DENABLE_TRANSI=OFF -DBUILD_SHARED_LIBS=OFF -DENABLE_TESTS=OFF -DECBUILD_2_COMPAT=ON -DECBUILD_2_COMPAT_DEPRECATE=OFF -DENABLE_SINGLE_PRECISION=ON -DENABLE_DOUBLE_PRECISION=OFF -DENABLE_GPU=OFF -DCMAKE_Fortran_FLAGS=\"${FRTFLAGS} -g -O1\"

GMK_CMAKE_field_api = -Wno-deprecated -Wno-dev -DCMAKE_C_COMPILER=\${VCCNAME} -DCMAKE_C_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS}\" -DCMAKE_CXX_COMPILER=\${CXXNAME} -DCMAKE_CXX_FLAGS=\"${VCCFLAGS} ${OPT_VCCFLAGS} ${MACROS_CXX}\" -DCMAKE_Fortran_COMPILER=\${FRTNAME} -DCMAKE_Fortran_FLAGS=\"${FRTFLAGS} ${OPT_FRTFLAGS}\" -DCMAKE_BUILD_TYPE=NONE -Dfiat_ROOT=\${TARGET_PACK}/\${GMK_HUB_DIR}/\${GMK_LAST_HUB_BRANCH}/\${GMK_HUB_INSTALL}/Fiat -DFYPP_PATH=\${GMK_FYPP}

# User libraries (absolute filename or short name) :
# ------------------------------------------------

# "Read Grib from BDAP":
LD_USR01 = $HOME/gpupack/install/$ARCH/lib/librgb.a
# "Bufr decoding":
LD_USR02 = $HOME/gpupack/install/$ARCH/lib/libbufr.a
# "Gribex (or emos)":
LD_USR04 = $HOME/gpupack/install/$ARCH/lib/libgribex.a
# "ecmwf field database":
LD_USR05 = $HOME/gpupack/install/$ARCH/lib/libfdbdummy.a
# "ecmwf wave model":
LD_USR06 = $HOME/gpupack/install/$ARCH/lib/libwamdummy.a
# "C code generated by blacklist":
LD_USR07 =
# "Nag":
LD_USR08 = $HOME/gpupack/install/$ARCH/lib/libnaglitedummy.a
# "OASIS":
LD_USR09 = $HOME/gpupack/install/$ARCH/lib/liboasisdummy.a
# "Grib_api":
LD_USR_GRIB_API_F90 = $HOME/gpupack/install/$ARCH/lib64/libeccodes_f90.so
LD_USR_GRIB_API = $HOME/gpupack/install/$ARCH/lib64/libeccodes.so
# "JPEG library":
LD_USR_JPEG =
# "EECFI" for aeolus:
LD_USR_EECFI =
# "Netcdf :"
LD_USR_NETCDF_F = $HOME/gpupack/install/$ARCH/lib64/libnetcdff.so
LD_USR_NETCDF = $HOME/gpupack/install/$ARCH/lib64/libnetcdf.so
# "HDF5 :"
LD_USR_HDF5_HLFORTRAN = $HOME/gpupack/install/$ARCH/lib/libhdf5_hl_fortran.so
LD_USR_HDF5_FORTRAN = $HOME/gpupack/install/$ARCH/lib/libhdf5_fortran.so
LD_USR_HDF5 = $HOME/gpupack/install/$ARCH/lib/libhdf5.so
# "Meteo-France dummies library (IFS only):"
LD_USR_MF_DUMMY =
# "Magics :"
LD_USR_MAGICS =
# "xml :"
LD_USR_XML = 

# Libraries from Hub :
# "eckit/fckit":
LD_USR_FCKIT = fckit
LD_USR_ECKIT_MPI = eckit_mpi
LD_USR_ECKIT = eckit
# "OOPS" :
LD_USR_OOPS = oops
# "Atlas" :
LD_USR_ATLAS_F = atlas_f
# parkind :
LD_USR_PARKIND = parkind_sp
# fiat :
LD_USR_FIAT = fiat
# ectrans :
LD_USR_ECTRANS = trans_sp
# field_api :
LD_USR_FIELD_API = field_api

# Language libraries (absolute filename or short name) :
# ----------------------------------------------------

# Lapack:
LD_LANG01 = $HOME/gpupack/install/$ARCH/lib64/liblapack.a
# Blas:
LD_LANG02 = $HOME/gpupack/install/$ARCH/lib64/libblas.a


# System-dependent libraries - ALWAYS LOADED - (absolute filename or short name) :
# ------------------------------------------------------------------------------

LD_SYS01 = $HOME/gpupack/install/$ARCH/lib/libibmdummy.so
LD_SYS02 =
LD_SYS03 =
LD_SYS04 =
LD_SYS05 =
LD_SYS06 =
LD_SYS07 =

# MPI libraries (absolute filename or short name) :
# -----------------------------------------------

LD_MPI01 =
LD_MPI02 =
LD_MPI03 =

LD_MPI_DUMMY = $HOME/gpupack/install/$ARCH/lib/libmpidummy.so

# Precompiler libraries
# ----------------------

LD_LIBC  =
LD_LIBM  =
LD_LIBVFL =

# External include pathes (path1:path2:...)
# ------------------------------------------

INCLUDEPATH = $HOME/gpupack/install/$ARCH/include:$HOME/gpupack/install/$ARCH/include:$HOME/gpupack/install/$ARCH/include:$HOME/gpupack/install/$ARCH/include/shared

# (Cross-) nm command & options for BSD format
# --------------------------------------------

NMOPTS = /usr/bin/nm 

# Native awk program
# ------------------

AWK = /bin/awk 

# (Cross-)archive
# ---------------

AR = /usr/bin/ar 

# Native archive
# --------------

ARNATIVE = /usr/bin/ar 

# Native preprocessor
# -------------------

CPP = /usr/bin/cpp 

# cmake executable
# ----------------

GMK_CMAKE = cmake

# Native lex program
# ------------------

LEX = flex -l

# Includes & modules
# ------------------

MODINC = -I
MODEXT = mod

# gget to recover volatile libraries
# ----------------------------------

GGET =

# External script used to generate and pre-process th blacklist file
# ------------------------------------------------------------------

GMK_BL_GENERATOR =

# Epilog of script
# ----------------

EPILOG = echo Finished on \$(date)

# Prefix of user's $(SHELL)rc file
# --------------------------------

GMKUSERFILE = 

# Prefix for root packs
# ---------------------

PACK_PREFIX =

# Suffix for root packs
# ---------------------

PACK_EXT =

# Binaries directory name
# -----------------------

GMKBIN = bin

# Libraries directory name
# ------------------------

GMKLIB = lib

# All-sources directory name
# --------------------------

GMKSRC = src

# Interfaces directory name for each branch
# -----------------------------------------

GMKINTFB = .intfb

# directory of .F90 files generated from .fypp files
# --------------------------------------------------

GMKFYPPF90 = .fypp

# MAIN (ie : bottom background) source directory name
# ---------------------------------------------------

GMKMAIN = main

# INTERMEDIATE (ie : intermediate background) source directory name
# -----------------------------------------------------------------

GMKINTER = inter

# LOCAL (ie : top) source directory name
# --------------------------------------

GMKLOCAL = local

# Unsatisfied external references main directory
# ----------------------------------------------

GMKUNSX = unsxref

# Quiet unsatisfied external references directory
# -----------------------------------------------

GMKUNSX_QUIET = quiet

# Verboose unsatisfied external references directory
# --------------------------------------------------

GMKUNSX_VERBOOSE = verbose

# system-program main directory
# -----------------------------

GMKSYS = sys

# Genesis file name
# -----------------

GMK_GENESIS = .genesis

# View file name
# --------------

GMK_VIEW = .gmkview

# Logfile name
# ------------

GMK_LOG = .logfile

# Scriptfile prefix
# -----------------

GMK_ICS = ics_

# Submission cards : number of nodes
# ----------------------------------

GMK_NQS_NODES = #SBATCH -N 1

# Submission cards : large memory
# -------------------------------

GMK_NQS_LARGE = 

# Submission cards : time limit
# -----------------------------

GMK_NQS_TIME  = #SBATCH --time=01:30:00

# Submission cards : output file KEY
# ----------------------------------

GMK_NQS_OUT_P = 

# Submission cards : error file KEY
# ---------------------------------

GMK_NQS_ERR_P = 

# Submission cards : output/error file stamp
# ------------------------------------------

GMK_NQS_JOBID = 

# Submission cards : other directives
# -----------------------------------
 
GMK_NQS_OTHER = #SBATCH --export=NONE
GMK_NQS_OTHER = #SBATCH --exclusive
GMK_NQS_OTHER = . $HOME/gpupack/gmkpack.sh
GMK_NQS_OTHER = 
GMK_NQS_OTHER = 
GMK_NQS_OTHER = 
GMK_NQS_OTHER = 

# Compiler feature extension for aeolus software
# ----------------------------------------------
GMK_AEOLUS_F90 = pgf90

# LatLon handling extension for aeolus software
# ---------------------------------------------
GMK_AEOLUS_LATLON_HANDLING = simple

