#!/bin/bash
########################################################################
#
#    Script bl95stuffpack
#    --------------------
#
#    Purpose : In the framework of a pack : to generate blacklist-related 
#    -------   source files
#
#    Usage : bl95stuffpack $1
#    -----
#               $1 : pack content to update (in/out)
#
#    Environment variables :
#    ---------------------
#            MKTOP      : directory of all source files
#            GMKWRKDIR     : main working directory
#            GMKROOT    : gmkpack root directory
#            MKMAIN
#            MODINC
#            AWK
#            CPP
#            MACROS_CC
#
########################################################################
#
export LC_ALL=C

packlist=$1

if [ $(grep ^bla\/ $packlist | wc -l) -ne 0 ] ; then
# Meteo-France naming convention
  VOB=bla
elif [ $(grep ^bl\/ $packlist | wc -l) -ne 0 ] ; then
# ECMWF naming convention
  VOB=bl
elif [ $(grep ^blacklist\/ $packlist | wc -l) -ne 0 ] ; then
# GCO naming convention
  VOB=blacklist
else
# No blacklist stuff
  exit 0
fi

MyTmp=$GMKWRKDIR/bl95stuffpack
mkdir -p $MyTmp
cd $MyTmp
#

# "Shrink" packlist by removing what is not-used
# ----------------------------------------------
#
echo Check $VOB project content ...
\cp $packlist packlist.bak
for dir in \
  compiler \
  ; do
  if [ $(grep ^${VOB}\/${dir}\/ $packlist | wc -l) -ne 0 ] ; then
    echo WARNING : Content of directory ${VOB}/$dir is now ignored :
    grep ^${VOB}\/${dir}\/ $packlist
    grep -v ^${VOB}\/${dir}\/ $packlist > mylist
    \mv mylist $packlist
  fi
done
#
cmp -s $packlist packlist.bak
if [ $? -ne 0 ] ; then
  echo
  echo ${VOB} final content :
  echo "================="
  grep ^${VOB}\/ $packlist
  echo
fi

grep -v "\.b$" $packlist > mylist
\mv mylist $packlist

export BL95NAME=$TARGET_PACK/$GMKSYS/bl95.x
#
# Build precompiler if source code has been detected and binary is absent :
# -----------------------------------------------------------------------
echo
if [ $(grep -c ^${VOB}\/compiler\/ packlist.bak) -ne 0 ] ; then
  if [ ! -f $BL95NAME ] ; then
    echo Build precompiler ...
    $GMKROOT/aux/syspack.sh bl95
    if [ $? -ne 0 ] || [ ! -f $BL95NAME ] ; then
      cd $GMKWRKDIR
      \rm -rf bl95stuffpack
      exit 1
    fi
  fi
fi
\rm packlist.bak

cd $GMKWRKDIR
\rm -rf bl95stuffpack
