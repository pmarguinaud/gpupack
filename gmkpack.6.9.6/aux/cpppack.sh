#!/bin/bash
########################################################################
#
#    Script cpppack
#    --------------
#
#    Purpose : In the framework of a pack : to preprocess in a local
#    -------   (ie distributed) framework
#
#              Treatment per kinds of files
#
#    Usage : cpppack $1 $2
#    -----
#              $1 : file list of element to compile
#              $2 : local directory for compilation
#
#    Environment variables :
#    ---------------------
#            ICS_INCPATH   : Paths for inclusions
#            GMKROOT       : gmkpack root directory
#            GMKVIEW       : list of branches, from bottom to top
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

# Use hidden files so that they wont be lost from one list to another:

PSEUDO_MKTOP=$PWD/$2
mkdir $PSEUDO_MKTOP

# no preprocessing for fortran : modules dependencies can't work recursively.
# no need for preprocessing for sql files
egrep -v "(\.h$|\.c$|\.cpp$|\.cc$)" $1 > $2/.subsublist
if [ -s $2/.subsublist ] ; then
#  echo "Descriptors for Fortran or sql files ..."
  export GMKLOCBR=$GMKLOCAL
  export MKBRANCHES="$GMKVIEW"
  export MKTMP=$PWD/$2
  cd $2
  ln -s .subsublist packlist
  $GMKROOT/aux/gmak.pl -d > /dev/null
  /bin/rm packlist
  mv local.sds local.sds.provi
  cd ..
fi

# headers as well as C or C++ code : 
egrep "(\.h$|\.c$|\.cpp$|\.cc$)" $1 > $2/.subsublist
if [ -s $2/.subsublist ] ; then
#  echo "Preprocessing of headers, c or c++ files ..."
  if [ "$CPP" ] ; then
    CPP_COMMAND="$CPP -dI -w -P"
  else
#   CPP is not defined, use the compiler instead :
    CPP_COMMAND="$VCCNAME -E -Wp,-dI -w -P"
  fi
# Shorten names of include directories:
  if [ -s $INCDIR_LIST ] ; then
    unset ICS_INCPATH
    i=0
    for absdir in $(cat $INCDIR_LIST) ; do
      i=$(($i+1))
      \ln -s $absdir $2/.D[$i]
      if [ $i -ne 1 ] ; then
        ICS_INCPATH="${ICS_INCPATH} ${MODINC}.D[${i}]"
      else
        ICS_INCPATH="${MODINC}.D[${i}]"
      fi
    done
  fi
  if [ $ICS_ECHO -gt 2 ] ; then
    ICS_ECHO_INCDIR="$ICS_INCPATH"
  fi
  FILES_LIST=$PWD/$2/.subsublist
  PSEUDO_MKMAIN=$PSEUDO_MKTOP/$GMKLOCAL
  mkdir -p $PSEUDO_MKMAIN
  cd $2
# There will be necessarily a file mpi.h at compile time ; fo now a dummy one is enough
# because what we want here is only to find out the files dependencies.
  touch mpi.h
  for vob in $(cut -d "/" -f1 $FILES_LIST | sort -u) ; do
    VOBNAME=$(echo $vob | tr '[a-z]' '[A-Z]')
    OPTVOB=GMK_CFLAGS_${VOBNAME}
#   headers should be free of dependencies, unless modules used => extract "use " statements only
#   (hopefully 1 per line !!) : 
    for file in $(grep "^${vob}/.*[h]$" $FILES_LIST) ; do
      if [ ! -d $PSEUDO_MKMAIN/$(dirname $file) ] ; then
        mkdir -p $PSEUDO_MKMAIN/$(dirname $file)
      fi
      grep -i '^[[:space:]]*use [[:space:]]*.*' $MKTOP/$GMKLOCAL/$file > $PSEUDO_MKMAIN/$file
    done
#   compilable files should show up the "include" directives used inside
#   in order to build the recursive dependencies => option -dI

#   C files :
    for file in $(grep "^${vob}/.*\.c$" $FILES_LIST) ; do
      if [ ! -d $PSEUDO_MKMAIN/$(dirname $file) ] ; then
        mkdir -p $PSEUDO_MKMAIN/$(dirname $file)
      fi
      CplOpts="$CPP_COMMAND -x c $MACROS_CC $(env | grep "^${OPTVOB}=" | cut -d"=" -f2-)"
#      echo "${CplOpts} ${ICS_ECHO_INCDIR} ${file}"
      eval $CplOpts $ICS_INCPATH -I. $MKTOP/$GMKLOCAL/$file > $PSEUDO_MKMAIN/$file
      if [ ! -f $PSEUDO_MKMAIN/$file ] ; then
        echo $file >> $CPP_ERRORLIST
      fi
    done

#   C++ files :
    for file in $(egrep "(^${vob}/.*\.cpp$|^${vob}/.*\.cc$)" $FILES_LIST) ; do
      if [ ! -d $PSEUDO_MKMAIN/$(dirname $file) ] ; then
        mkdir -p $PSEUDO_MKMAIN/$(dirname $file)
      fi
      CplOpts="$CPP_COMMAND -x c++ $MACROS_CXX $(env | grep "^${OPTVOB}=" | cut -d"=" -f2-)"
#      echo "${CplOpts} ${ICS_ECHO_INCDIR} ${file}"
      eval $CplOpts $ICS_INCPATH -I. $MKTOP/$GMKLOCAL/$file > $PSEUDO_MKMAIN/$file
      N=$?
      if [ $N -ne 0 ] ; then
        echo $file >> $CPP_ERRORLIST
      fi
    done

  done
  cd ..
  #echo "Descriptors of headers, c or c++ files ..."
# for gmak.pl :
  export MKTOP=$PSEUDO_MKTOP
  export MKMAIN=$PSEUDO_MKMAIN
  export GMKLOCBR=$GMKLOCAL
  export MKBRANCHES="$GMKVIEW"
  export MKTMP=$MKTOP
  cd $MKMAIN
  $GMKROOT/util/scanpack > $MKTMP/packlist
  cd $MKTMP
  $GMKROOT/aux/gmak.pl -d > /dev/null
  /bin/rm packlist
  cat local.sds >> $PSEUDO_MKTOP/local.sds.provi
fi

sort $PSEUDO_MKTOP/local.sds.provi > $PSEUDO_MKTOP/local.sds
cd ..

