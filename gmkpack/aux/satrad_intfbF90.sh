#!/bin/bash
########################################################################
#
#    Script intfbF90
#    ---------------
#
#    Purpose : In the framework of a pack : F90 precompiler for explicit interfaces
#    -------
#
#    Usage : intfbF90 $1 $2 $3 $4
#    -----
#            $1 : filename to treat
#            $2 : output listing (if precompilation fails)
#            $3 : true compilation command
#
#    Environment variables :
#    ---------------------
#            GMKROOT        : gmkpack root directory
#            MKTOP          : directory of all source files
#            GMKINTFB       : relative auto-generated interfaces blocks directory
#            ICS_ECHO       : Verboose level
#            ICS_VPATH      : Normal pathes for include files
#            GMKUNSX        : relative directory for unsatisfied external -main
#            GMKUNSX_QUIET : relative directory for unsatisfied external -quiet
#            GMKUNSX_VERBOOSE : relative directory for unsatisfied external -verboose
#            MKLIB          : libraries directory
#            AWK            : awk program 
#            AR             : ar command
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

# Precompile
# ----------
if [ $ICS_ECHO -gt 2 ] ; then
  echo intfbF90 $1 $2
fi
$GMKROOT/aux/my_check_inc_intfb.pl $1 1> intfb_report 2>&1
  \mv intfb_report intfb_list
  grep "^#include [^ ]" $1 | grep -v "\.intfb\.h" | cut -d" " -f2 | cut -d'"' -f2 > explicit
  grep "^INCLUDE [^ ]" intfb_list | cut -d" " -f2 | sort -u > include
  grep "^CALL [^ ]" intfb_list | cut -d" " -f2 | sort -u > calls
  \rm -f intfb_fatal
# The following test cannot work as soon as the (satrad) interface generator makes interfaces for
# function (this never happens for arpege/ifs) ; until the check_inc_intfb.pl becomes able to detect
# functions. Not-modular headers as is the coding style in satrad makes this test even less reliable.
#  for subroutine in $(comm -23 include calls) ; do
#    echo USELESS INTERFACE BLOCK - REMOVE LINE : \#include \"${subroutine}.intfb.h\" >> intfb_fatal
#  done
  for subroutine in $(comm -13 include calls) ; do
    if [ $(grep -c ${subroutine}.h explicit) -eq 0 ] ; then
      if [ $(find $MKTOP/*/$GMKINTFB/* -name "${subroutine}.intfb.h" -print | wc -l) -ne 0 ] ; then
        echo MISSING INTERFACE BLOCK FOR SUBROUTINE - ADD LINE : \#include \"${subroutine}.intfb.h\" >> intfb_fatal
      fi
    fi
  done
  if [ -s intfb_fatal ] ; then
    cat $1 > $2
    echo >> $2
    echo "Interface blocks checker diagnostic messages 1 : file $1" >> $2
    cat intfb_report intfb_fatal 1>> $2 2>/dev/null
  else
    eval "$3 $1 2> err"
    if [ -f $2 ] ; then
      echo >> $2
      if [ -s err ] ; then
        cat err >> $2
        echo >> $2
      fi
      echo "Interface blocks checker diagnostic messages 3 : file $1" >> $2
      cat intfb_report 1>> $2 2>/dev/null
      echo >> $2
    else
      if [ -s err ] ; then
        cat err
      fi
    fi
  fi
  for subroutine in $(comm -12 include calls) ; do
    \rm -f ${subroutine}.intfb.h
  done
  \rm -f calls include explicit
\rm -f intfb_report intfb_fatal intfb_list err
