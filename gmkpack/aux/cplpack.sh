#!/bin/bash
########################################################################
#
#    Script cplpack
#    --------------
#
#    Purpose : In the framework of a pack : to compile in a local
#    -------   (ie distributed) framework
#
#              Treatment per kinds of files
#
#    Usage : cplpack $1 $2
#    -----
#              $1 : file list of element to compile
#              $2 : directory for compilation
#              $3 : file list of directories to add to include/modules path
#
#    Environment variables :
#    ---------------------
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

mkdir $2
# Shorten names of include directories:
if [ -s $INCDIR_LIST ] ; then
  i=0
  unset ICS_INCPATH ICS_VPATH
  for absdir in $(cat $INCDIR_LIST) ; do
    i=$(($i+1))
    \ln -s $absdir $2/.D[$i]
    if [ $i -ne 0 ] ; then
      ICS_INCPATH="${ICS_INCPATH} ${MODINC}.D[${i}]"
      ICS_VPATH="${ICS_VPATH}:.D[${i}]"
    else
      ICS_INCPATH="${MODINC}.D[${i}]"
      ICS_VPATH=".D[${i}]"
    fi
  done
fi
export ICS_INCPATH
export ICS_VPATH
export VPATH=$ICS_VPATH

if [ $ICS_ECHO -gt 2 ] ; then
  export ICS_ECHO_INCDIR="$ICS_INCPATH"
fi

# Safe initialization of timing report variables :
if [ ! "$ICS_TIMING_REPORT" ] ; then
  export ICS_TIMING_REPORT=0
else
  if [ ! "$GMK_TIMEFILE_EXTENSION" ] ; then
    export GMK_TIMEFILE_EXTENSION="time"
  fi
fi

# Use hidden files so that they wont be lost from one list to another:
for branch in $(cut -d "@" -f1 $1 | sort -u) ; do
  grep "^${branch}@" $1 | cut -d "@" -f2 > $2/.sublist

  grep "\.y$" $2/.sublist > $2/.subsublist
  if [ -s $2/.subsublist ] ; then
    $GMKROOT/aux/YACC_cplpack.sh $2/.subsublist $2 $branch
  fi

  grep "\.l$" $2/.sublist > $2/.subsublist
  if [ -s $2/.subsublist ] ; then
    $GMKROOT/aux/LEX_cplpack.sh $2/.subsublist $2 $branch
  fi

  grep "\.c$" $2/.sublist > $2/.subsublist
  if [ -s $2/.subsublist ] ; then
    $GMKROOT/aux/C_cplpack.sh $2/.subsublist $2 $branch
  fi

  egrep "(\.cpp$|\.cc$)" $2/.sublist > $2/.subsublist
  if [ -s $2/.subsublist ] ; then
    $GMKROOT/aux/Cpp_cplpack.sh $2/.subsublist $2 $branch
  fi

  egrep "(\.cu$)" $2/.sublist > $2/.subsublist
  if [ -s $2/.subsublist ] ; then
    $GMKROOT/aux/Cu_cplpack.sh $2/.subsublist $2 $branch
  fi

  grep "\.sql$" $2/.sublist > $2/.subsublist
  if [ -s $2/.subsublist ] ; then
    $GMKROOT/aux/SQL_cplpack.sh $2/.subsublist $2 $branch
  fi

  egrep -v "(\.cu$|\.c$|\.cpp$|\.sql$|\.cc$|\.y$|\.l$)" $2/.sublist > $2/.subsublist
  if [ -s $2/.subsublist ] ; then
    $GMKROOT/aux/FORTRAN_cplpack.sh $2/.subsublist $2 $branch $3
  fi

done
