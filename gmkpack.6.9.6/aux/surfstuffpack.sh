#!/bin/bash
########################################################################
#
#    Script surstuffpack
#    --------------------
#
#    Purpose : In the framework of a pack : to remove what is not used from
#    -------   ec externalised surface
#
#    Usage : surstuffpack $1
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

if [ $(grep ^sur\/ $packlist | wc -l) -ne 0 ] ; then
# Meteo-France naming convention
  VOB=sur
elif [ $(grep ^surf\/ $packlist | wc -l) -ne 0 ] ; then
# ECMWF naming convention
  VOB=surf
else
# No EC surface stuff
  exit 0
fi

MyTmp=$GMKWRKDIR/surstuffpack
mkdir -p $MyTmp
cd $MyTmp
#
# "Shrink" packlist by removing what is not-used
# ----------------------------------------------
#
echo Check $VOB content ...
\cp $packlist packlist.bak
for dir in \
  offline \
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
\rm packlist.bak

cd $GMKWRKDIR
\rm -rf surstuffpack
