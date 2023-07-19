#!/bin/bash
########################################################################
#
#    Script link
#    --------------
#
#    Purpose : In the framework of a pack : to link headers into a directory as a shortcut
#    ------- 
#
#    Usage : link $1
#    -----
#              $1 : file list of element to link
#              $2 : provisional list of include directives
#
#    Environment variables :
#    ---------------------
#
########################################################################
#
export LC_ALL=C

/bin/cp $INCDIRS $2
for element in $(cat $1) ; do
  vob=$(echo $element | cut -d "/" -f1)
  basefile=$(basename $element)
  if [ $(grep -c ^${MODINC}${MKMAIN}/.include/$vob/headers$ $2) -eq 0 ] ; then
    mkdir -p      ${MKMAIN}/.include/$vob/headers 2>/dev/null
    echo ${MODINC}${MKMAIN}/.include/$vob/headers >> $2
  fi
  if [ ! -h $MKMAIN/.include/$vob/headers/$basefile ] ; then
    \ln -sf ../../../$element $MKMAIN/.include/$vob/headers/$basefile
  fi
done

