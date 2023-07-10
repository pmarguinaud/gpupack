#!/bin/bash
########################################################################
#
#    Script Pcplpack
#    --------------
#
#    Purpose : In the framework of a pack : distribute compilation then
#    -------   submit distributed compilation
#
#    Usage : Pcplpack $1
#    -----
#              $1 : global file list of element to compile
#              $2 : global file list of added directories for include/modules path
#
#    Environment variables :
#    ---------------------
#            GMK_THREADS : number threads
#            GMKWRKDIR   : main working directory
#            GMKROOT     : gmkpack root directory
#
########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

if [ -s $1 ] ; then
  echo Compile:
  MyTmp=$GMKWRKDIR/Pcplpack
  Dirwork=$MyTmp/dirwork
  mkdir -p $MyTmp
# Submit parallel compilation :
  $GMKROOT/aux/mpsh_driver.sh $GMKROOT/aux/cplpack.sh $1 $Dirwork $MyTmp/more_incdir
  sleep 1
  cat $MyTmp/more_incdir.* 2>/dev/null | sort -u > $2
  \rm -rf $MyTmp
fi
