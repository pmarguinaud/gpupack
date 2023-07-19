#!/bin/bash
########################################################################
#
#    Script Pupdpack
#    --------------
#
#    Purpose : In the framework of a pack : distribute throug compilation
#    -------   list then submit update for compilation
#
#    Usage : Pupdpack $1 $2 $3 $4 $5
#    -----
#            $1 : (input) file containing the list of elements to update
#            $2 : (output) restricted list of element to compile
#            $3 : (output) restricted list of object file to get
#            $4 : (input) descriptors for all modules in compilation list
#            $5 : (input) list of all files
#
#    Environment variables :
#    ---------------------
#            GMK_THREADS : number of threads
#            GMKWRKDIR   : main working directory
#            GMKROOT     : gmkpack root directory
#
########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

if [ -s $1 ] ; then

  echo Recursive update:
  \rm -f $2 $3
  touch $2 $3

  MyTmp=$GMKWRKDIR/Pupdpack
  mkdir -p $MyTmp

  List=$MyTmp/list
  Outsrc=$MyTmp/outsrc
  Outobj=$MyTmp/outobj
  ln -s -f $1 $List
  export ALL_DESCRIPTORS=$4
  export ALL_FILES_LIST=$5
# Submit parallel update :
  $GMKROOT/aux/mpsh_driver.sh $GMKROOT/aux/updpack.sh $List $Outsrc $Outobj $MyTmp
  cat ${Outsrc}.* 1> $2 2>/dev/null
  cat ${Outobj}.* 1> $3 2>/dev/null
  \rm -rf $MyTmp

fi

