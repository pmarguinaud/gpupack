#!/bin/bash
########################################################################
#
#    Script arpifs_norms_checker
#    ---------------------------
#
#    Purpose : In the framework of a pack : arpege/Ifs norms checker
#    -------
#
#    Usage : arpifs_norms_checker $1 $2 $3
#    -----
#            $1 : filename to treat
#            $2 : output listing of the treated file
#            $3 : norms report of the treated file
#
#    Environment variables :
#    ---------------------
#            GMKROOT        : gmkpack root directory
#            MKTOP          : directory of all source files
#            GMKINTFB       : relative auto-generated interfaces blocks directory
#            ICS_ECHO       : Verboose level
#            ICS_VPATH      : Normal pathes for include files
#
########################################################################
#
export LC_ALL=C

SRCFILE=$1
LISTING=$2
REPORT=$3

if [ $ICS_ECHO -gt 2 ] ; then
  echo arpifs_norms_checker on $SRCFILE
fi

if [ "$GMK_NORMS_CHECKER" != "2003" ] ; then
# INTFBDIR is here (as dummy) just to please the norms checker ; but it is not used, actually.
  export INTFBDIR=$GMKINTFB
  $GMKROOT/aux/check_norm_2011.pl $SRCFILE 1> $REPORT 2>&1
else
  $GMKROOT/aux/my_check_norm.pl $SRCFILE 1> $REPORT 2>&1
fi
if [ -s $REPORT ] ; then
  if [ -f $LISTING ] ; then
    echo >> $LISTING
    echo "Norms checker report :" >> $LISTING
    echo >> $LISTING
    cat $REPORT >> $LISTING 2>/dev/null
  fi
fi
