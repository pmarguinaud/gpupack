#!/bin/bash
########################################################################
#
#    Script Pcpppack.sh
#    --------------
#
#    Purpose : In the framework of a pack : distribute compilation then
#    -------   submit distributed compilation
#
#    Usage : Pcpppack.sh $1 $2
#    -----
#              $1 : global file list of element to compile
#              $2 : global file of gmak descriptors
#              $3 : global file list of compilable files which failed at preprocessing
#
#    Environment variables :
#    ---------------------
#            GMK_THREADS : number threads
#            GMKWRKDIR   : main working directory
#            GMKROOT     : gmkpack root directory
#
########################################################################

export LC_ALL=C

DIR=$PWD
Dirwork=dirwork

List=$1

if [ -s $List ] ; then

  export CPP_ERRORLIST=error.list

# Submit parallel compilation :
  $GMKROOT/aux/mpsh_driver.sh $GMKROOT/aux/cpppack.sh $List $Dirwork

  cd $DIR
# Concatenate output files :
  cat $(find ${Dirwork}.* -name "local.sds") | sort  > $2
# Concatenate error list :
  find ${Dirwork}.* -name "$CPP_ERRORLIST" | xargs cat | sort  > $3

  /bin/rm -rf ${Dirwork}.* ${List}.*

fi
