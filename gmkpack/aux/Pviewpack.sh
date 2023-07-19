#!/bin/bash
########################################################################
#
#    Script Pviewpack
#    --------------
#
#    Purpose : In the framework of a pack : distribute elements
#    -------   to make "view" descriptors files
#
#    Usage : Pviewpack $1 $2
#    -----
#            $1 : (input) list of files
#            $2 : (output) file containing the list of descriptors
#
#    Environment variables :
#    ---------------------
#            GMK_THREADS : number of threads
#            GMKWRKDIR   : main working directory
#            GMKROOT     : gmkpack root directory
#
########################################################################
#

export LC_ALL=C

if [ -s $1 ] ; then
  MyTmp=$GMKWRKDIR/Pviewpack
  mkdir -p $MyTmp
  Viewlist=$MyTmp/viewlist
# Submit parallel description :
  $GMKROOT/aux/mpsh_driver.sh $GMKROOT/aux/viewpack.sh $1 $Viewlist
  cat ${Viewlist}.* > $2
  \rm -rf $MyTmp
fi
