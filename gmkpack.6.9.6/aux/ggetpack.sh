#!/bin/bash
########################################################################
#
#    Script ggetpack
#    --------------
#
#    Purpose : In the framework of a pack : to prepare link edition by
#    -------   getting all the needed libraries
#
#    Usage : ggetpack
#    -----
#
#    Environment variables :
#    ---------------------
#            GMKWRKDIR    : main working directory
#            ROOTPACK  : *gco* homepack
#            ICS_ERROR : error file
#            MKLIB     : directory for libraries
#            AWK       : awk program
#            GMKROOT   : gmkpack root directory
#            GGET
#
########################################################################
#
export LC_ALL=C

MyTmp=$GMKWRKDIR/ggetpack
if [ ! -d $MyTmp ] ; then
  mkdir -p $MyTmp
fi
find $MyTmp -name "*" -type f | xargs /bin/rm -f
#
for lib in $* ; do
  link=$(\ls -l $(\ls -l $lib | $AWK '{print $NF}' | $AWK '{print $NF}') | $AWK '{print $NF}')
  dirlink=$(dirname $link)
  baselink=$(basename $link)
  cd $dirlink
  if [ ! -f $baselink ] ; then
#   Library does not exist, let s try to recover it if the recovering tool exists :
    if [ "$GGET" ] ; then
      cd $MyTmp
      echo "$GGET $baselink"
      $GGET $baselink
      \rm -f ftpget.*
      cd $dirlink
    fi
  fi
  if [ ! -f $baselink ] ; then
#   Library could not be recovered  
    echo "ggetpack failure for library " $lib >> $MyTmp/report
  fi
done
#
cd $MyTmp
if [ -s report ] ; then
  touch $ICS_ERROR
  cat report
  cd $GMKWRKDIR
  \rm -rf ggetpack
  exit 1
else
  cd $GMKWRKDIR
  \rm -rf ggetpack
fi
