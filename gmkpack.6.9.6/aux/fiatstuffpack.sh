#!/bin/bash
########################################################################
#
#    Script fiatstuffpack
#    --------------------
#
#    Purpose : In the framework of a pack : to remove what is not used from
#    -------   ec externalised surface
#
#    Usage : fiatstuffpack $1
#    -----
#               $1 : pack content to update (in/out)
#
#    Environment variables :
#    ---------------------
#
########################################################################
#
export LC_ALL=C

packlist=$1

VOB=fiat

MyTmp=$GMKWRKDIR/${VOB}stuffpack
mkdir -p $MyTmp
cd $MyTmp
#
# Shrink packlist by removing what is not used
# --------------------------------------------
# HERE : mpl_serial MUST be excluded or it will conflict with the true mpi library
#
\cp $packlist packlist.bak
echo Check $VOB content ...
grep -v "${VOB}\/" packlist.bak > $packlist
dirlist="src/fiat src/parkind"
echo "WARNING : Content of directory ${VOB} is restricted to the following directories : $dirlist"
for dir in $(eval echo $dirlist) ; do
    grep ^${VOB}\/${dir}\/ packlist.bak >> $packlist
done
#
cd $GMKWRKDIR
\rm -rf ${VOB}stuffpack
