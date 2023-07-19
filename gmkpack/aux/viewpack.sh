#!/bin/bash
########################################################################
#
#    Script viewpack
#    --------------
#
#    Purpose : In the framework of a pack : to select the descriptors
#    -------   of elements to be compiled
#
#    Usage : viewpack $1 $2
#    -----
#            $1 : (input) file containing the list of elements
#            $2 : (output) file containing the list of descriptors
#
#    Environment variables :
#    ---------------------
#            MKTOP     : directory of all source files
#
########################################################################
#
export LC_ALL=C

\rm -f $2
touch $2
for element in $(cat $1) ; do
  branch=$(echo $element | cut -d"@" -f1)
  file=$(echo $element | cut -d"@" -f2)
  if [ -f $GMAKDIR/${branch}.sds ] ; then
    grep $file $GMAKDIR/${branch}.sds >> $2
  else
   echo viewpack error : no file $GMAKDIR/${branch}.sds
  fi
done
