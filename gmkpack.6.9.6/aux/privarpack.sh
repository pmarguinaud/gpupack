#!/bin/bash
########################################################################
#
#    Script privarpack
#    -----------------
#
#    Purpose : In the framework of a pack : to make the list of "export" statements
#    -------   for private environment variables used by a compilation script.
#
#    Usage : privarpack
#    -----
#    Parameters : none. 
#    ----------
#
########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

# ICS_PRJS : list of projects present in this pack:
echo "export ICS_PRJS=\"$(echo $(\ls -1dp \
  $TARGET_PACK/$GMKSRC/$GMKMAIN/* $TARGET_PACK/$GMKSRC/${GMKINTER}*/* $TARGET_PACK/$GMKSRC/$GMKLOCAL/* \
  2>/dev/null | grep "/$" | sed "s/\/$//" | $AWK -F "/" '{print $NF}' | grep -v "^\.$" | sort -u))\""
echo "export MKLINK=$TARGET_PACK/$GMKBIN"
echo "export MKLIB=$TARGET_PACK/$GMKLIB"
echo "export MKTOP=$TARGET_PACK/$GMKSRC"
echo "export MKMAIN=\$MKTOP/$GMKLOCAL"
echo "export F90Flags=\"$OPT_FRTFLAGS\""
echo "export F77Flags=\"$OPT_FRTFLAGS\""
echo "export VccFlags=\"$OPT_VCCFLAGS\""
echo "export CcuFlags=\"$OPT_CCUFLAGS\""

GMK_TIMER=${GMK_TIMER:=/usr/bin/time}
echo "export GMK_TIMER=\"$GMK_TIMER\""

echo "if [ \"\$GMK_LOCAL_PROFILE\" ] ; then"
echo "  PROFILE=\$(which \$GMK_LOCAL_PROFILE)"
echo "  if [ \"\$PROFILE\" ] ; then"
echo "    . \$PROFILE"
echo "  fi"
echo "fi"

