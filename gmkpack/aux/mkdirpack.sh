#!/bin/bash
########################################################################
#
#    Script mkdirpack
#    ----------------
#
#    Purpose : In the framework of a pack : to recursively create all
#    -------   mirrors directories from a reference directories tree.
#
#    Usage :  mkdirpack $1
#    -----
#             $1 : absolute pack name
#
#    Environment variables :
#    ---------------------
#          GMKLOCAL: local source directory
#          GMKSRC  : sources directory
#          GMK_VIEW: pack view
#
########################################################################
#
export LC_ALL=C

# Directory where to store F90 files generated from .fypp files
if [ ! "$GMKFYPPF90" ] ; then
  export GMKFYPPF90=.fypp
fi

cd $1
# Search in all branches but the local one, starting from the bottom one :
for branch in $(sed '2!G;h;$!d' $GMK_VIEW) ; do
  cd $GMKSRC
# Search in all projects :
  for vob in $(\ls $branch) ; do
    if [ -d $branch/$vob ] ; then
      echo $branch tree for $vob ...
      cd $branch
      for dir in $(find $vob -type d -print) ; do
        \mkdir -p $1/$GMKSRC/$GMKLOCAL/$dir
      done
      cd ..
    fi
    if [ -d $branch/$GMKFYPPF90/$vob ] ; then
      echo $branch tree for $GMKFYPPF90/$vob ...
      cd $branch
      for dir in $(find $GMKFYPPF90/$vob -type d -print) ; do
        \mkdir -p $1/$GMKSRC/$GMKLOCAL/$dir
      done
      cd ..
    fi
  done
  cd ..
done
