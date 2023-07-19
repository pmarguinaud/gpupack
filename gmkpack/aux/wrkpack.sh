#!/bin/bash
########################################################################
#
#    Script wrkpack
#    --------------
#
#    Purpose : In the framework of a pack : to create/clean the working
#    -------   directory
#
#    Usage : . wrkpack.sh
#
########################################################################
#
export LC_ALL=C

export GMKTMP=${GMKTMP:=/tmp}
export GMKWRKDIR=$GMKTMP/gmktmp.$$

trap "cd $GMKTMP ; \rm -rf gmktmp.$$ ; echo Working directory removed ; exit 1" 2 6 9 14 15 20

mkdir -p $GMKWRKDIR 2> /dev/null
if [ ! -d $GMKWRKDIR ] ; then
  echo directory $GMKWRKDIR could not be created
  exit 1
else
  echo GMKWRKDIR=$GMKWRKDIR
  for file in $(\ls -1a $GMKWRKDIR | grep -v "^\.*\.$") ; do
    \rm -rf $GMKWRKDIR/$file
  done
fi
