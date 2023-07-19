#!/bin/bash
########################################################################
#
#    Script licensepack
#    ----------------
#
#    Purpose : In the framework of a pack : to control the use of interactive 
#    -------   mode and the match of the compilation script with the current
#              gmkpack version.
#
#    Usage : licensepack
#    -----
#
#    Environment variables :
#    ---------------------
#            GMKROOT        : gmkpack root directory
#            GMKFILE        : architecture file name
#            LOGNAME        : user logname
#            ENVIRONMENT    : environment mode
#
########################################################################

export LC_ALL=C

if [ "$ENVIRONMENT" = "INTERACTIVE" ] || [ "$ENVIRONMENT" != "BATCH" ] ; then
  if [ -f $GMKROOT/licensed/$GMKFILE ] ; then
    if [ $(grep -c "^$LOGNAME$" $GMKROOT/licensed/$GMKFILE) -eq 0 ] ; then
      echo
      echo " INTERACTIVE MODE IS NOW CURRENTLY OFF."
      echo " To enable it, apply for it to your gmkpack administrator."
      echo " Your environment : $ENVIRONMENT"
      exit 1
    fi
  fi
fi

GMK_SUPPORT=${GMK_SUPPORT:=$PREFIX/gmkpack/support}

if [ "$(\ls -1t $TARGET_PACK/.gmkfile 2>/dev/null | tail -1)" ] ; then
  GMKFILEPATH=$TARGET_PACK/.gmkfile
  FLAVOUR=$(\ls -1t $GMKFILEPATH | tail -1)
elif [ -f $HOME/.gmkpack/arch/$GMKFILE.$GMK_OPT ] ; then
  GMKFILEPATH=$HOME/.gmkpack/arch
  FLAVOUR=$GMKFILE.$GMK_OPT
elif [ -f $GMK_SUPPORT/arch/$GMKFILE.$GMK_OPT ] ; then
  GMKFILEPATH=$GMK_SUPPORT/arch
  FLAVOUR=$GMKFILE.$GMK_OPT
else
  echo "Error : no file ${GMKFILE}* could be found either in source pack, \$HOME/.gmkpack/arch or \$GMK_SUPPORT/arch."
  exit 1
fi
if [ $(grep -c LD_SYS05 $GMKFILEPATH/$FLAVOUR) -eq 0 ] ; then
  echo
  echo " This script does not match the version of gmkpack you are using."
  echo " You should remake your script."
  exit 1
fi
if [ ! "$GMKWRKDIR" ] ; then
  echo
  echo " This script does not match the version of gmkpack you are using."
  echo " You should remake your script."
  exit 1
fi
if  [ $(grep -c GMK_SUPPORT $GMKFILEPATH/$FLAVOUR) -ne 0 ] && [ ! "$GMK_SUPPORT" ] ; then
  echo
  echo " Fatal ! You are using a wrapper but the variable GMK_SUPPORT is not set."
  exit 1
fi
