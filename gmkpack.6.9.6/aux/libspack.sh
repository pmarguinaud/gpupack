#!/bin/bash
########################################################################
#
#    Script libspack
#    --------------
#
#    Purpose : In the framework of a pack : to make archive libraries
#    -------
#
#    Usage : libspack
#    -----
#
#    Environment variables :
#    ---------------------
#            MKLIB     : directory of libraries
#            MKLINK    : directory of binaries
#            MKTOP     : directory of all source files
#            GMKWRKDIR    : main working directory
#            AWK       : awk program
#            AR        : ar command
#            GMKROOT   : gmkpack root directory
#            ICS_PRJS  : list of all projects
#
########################################################################

export LC_ALL=C

$GMKROOT/aux/licensepack.sh
if [ $? -ne 0 ] ; then
  exit 1
fi

export ICS_PROJLIBS="$ICS_PRJS"

# Check mode (keep "yes" and "no" for compatibility with the previous versions) :
if [ "$ICS_UPDLIBS" != "yes" ] && [ "$ICS_UPDLIBS" != "full" ] && [ "$ICS_UPDLIBS" != "user" ] && [ "$ICS_UPDLIBS" != "dummy" ] && [ "$ICS_UPDLIBS" != "off" ] && [ "$ICS_UPDLIBS" != "no" ] && [ "$ICS_UPDLIBS" != "unsx" ] ; then
  ICS_UPDLIBS=full
fi

if [ "$ICS_UPDLIBS" = "off" ] || [ "$ICS_UPDLIBS" = "no" ] ; then
  echo
  echo "         #    #    ##    #####   #    #     #    #    #   ####"
  echo "         #    #   #  #   #    #  ##   #     #    ##   #  #    #"
  echo "         #    #  #    #  #    #  # #  #     #    # #  #  #"
  echo "         # ## #  ######  #####   #  # #     #    #  # #  #  ###"
  echo "         ##  ##  #    #  #   #   #   ##     #    #   ##  #    #"
  echo "         #    #  #    #  #    #  #    #     #    #    #   ####"
  echo
  echo "               LIBRARIES ARE NOT UPDATED. "
  echo "          PROCEEDING BINARIES MIGHT BE UNSAFE !"
  echo
  exit 0
fi

ICS_LIBS_ERROR=0

if [ "$ICS_UPDLIBS" = "yes" ] || [ "$ICS_UPDLIBS" = "full" ] || [ "$ICS_UPDLIBS" = "user" ] ; then
# Update user libraries :
  $GMKROOT/aux/userlibspack.sh
  if [ $? -ne 0 ] ; then
    ICS_LIBS_ERROR=1
    exit 1
  fi
else
  echo
  echo "                       WARNING ! "
  echo
  echo "           USER LIBRARIES UPDATE IS SKIPPED. "
  echo "          PROCEEDING BINARIES MIGHT BE UNSAFE !"
  echo
fi

if [ "$ICS_UPDLIBS" = "yes" ] || [ "$ICS_UPDLIBS" = "full" ] || [ "$ICS_UPDLIBS" = "unsx" ] ; then
# Update unsatisfied external libraries
  $GMKROOT/aux/unsxrpack.sh
  if [ $? -ne 0 ] ; then
    ICS_LIBS_ERROR=1
    exit 1
  fi
else
  echo
  echo "                       CAUTION"
  echo
  echo "    UNSATISFIED EXTERNAL LIBRARIES UPDATE IS SKIPPED. "
  echo "               LINKING EDITION MIGHT FAIL."
fi

if [ "$ICS_UPDLIBS" = "yes" ] || [ "$ICS_UPDLIBS" = "full" ] || [ "$ICS_UPDLIBS" = "dummy" ] ; then
# Update dummies libraries :
  $GMKROOT/aux/dummylibspack.sh
  if [ $? -ne 0 ] ; then
    ICS_LIBS_ERROR=1
    exit 1
  fi
else
  echo
  echo "                       CAUTION"
  echo
  echo "          DUMMY LIBRARIES UPDATE IS SKIPPED. "
  echo "             LINKING EDITION MIGHT FAIL."
fi

if  [ $ICS_LIBS_ERROR -eq 1 ] ; then
  exit 1
fi

exit 0
