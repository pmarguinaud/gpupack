#!/bin/bash
########################################################################
#
#    Script vppstuffpack
#    -------------------
#
#    Purpose : In the framework of a pack : to compile handle vpp-specific
#    -------   routines
#
#    Usage : vppstuffpack $1
#    -----
#               $1 : pack content to update (in/out)
#
#    Environment variables :
#    ---------------------
#            GMKWRKDIR     : main working directory
#
########################################################################
#
export LC_ALL=C

packlist=$1
#
# "Shrink" packlist by removing what is not-used
# ----------------------------------------------
#
if [ $(grep -c "\.vpp\.F$" $packlist) -ne 0 ] ; then

# Set wrk directory
  MyTmp=$GMKWRKDIR/vppstuffpack
  mkdir -p $MyTmp
  cd $MyTmp

# Architecture
  if [ "$(arch 2>/dev/null)" = "5000" ] ; then
    VPP=yes
  else
    unset VPP
  fi

  \cp $packlist packlist.bak
  if [ ! "$VPP" ] ; then
    grep "\.vpp\.F$" packlist.bak > packlist.vpp
    if [ -s packlist.vpp ] ; then
      echo WARNING : VPP-specific files are now ignored :
      cat packlist.vpp
      grep -v "\.vpp\.F$" packlist.bak > $packlist
    fi
  else
    for file in $(grep "\.vpp\.F$" $packlist | sed "s/\.vpp\.F$//" | $AWK -F"/" '{print $NF}') ; do
      grep "/${file}\.F$" $packlist >> novpplist
    done
    echo WARNING : non-VPP-specific files are now ignored :
    cat novpplist
    comm -13 novpplist packlist.bak > $packlist
  fi

# Finish
  cd $GMKWRKDIR
  \rm -rf vppstuffpack

fi
