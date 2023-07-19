#!/bin/bash
########################################################################
#
#    Script Plink
#    --------------
#
#    Purpose : In the framework of a pack : distribute link shortcut for headers
#    -------   prior to preprocessing
#
#    Usage : Plink $1
#    -----
#              $1 : global file list of element to link
#
#    Environment variables :
#    ---------------------
#            GMK_THREADS : number threads
#            GMKWRKDIR   : main working directory
#            GMKROOT     : gmkpack root directory
#
########################################################################

export LC_ALL=C

if [ -s $1 ] ; then
  incdirs=$INCDIRS
  $GMKROOT/aux/mpsh_driver.sh $GMKROOT/aux/link.sh $1 $incdirs
  cat ${incdirs}.* | sort -u > $INCDIRS
  /bin/rm ${incdirs}.*
fi
