#!/bin/bash
########################################################################
#
#    Script catenvpack
#    -----------------
#
#    Purpose : In the framework of a pack : to list the values af the 
#    -------   environment variables actually used (and actually set)
#              and make some private ones
#
#    Usage : catenvpack
#    -----
#    Parameters : none. 
#    ----------
#
########################################################################
export LC_ALL=C

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
  \rm -rf $GMKWRKDIR
  exit 1
fi

\rm -f $GMKWRKDIR/gmkpack_actual_variables

grep '^[A-Z]' $GMKFILEPATH/$FLAVOUR | grep -v ^GMK_NQS_ | cut -d " " -f1 | sed "s/\(.*\)/echo \1=\$\1/" > $GMKWRKDIR/gmkpack_actual_variables

for VAR in ICS_PRJS MKLINK MKLIB MKTOP MKMAIN F90Flags F77Flags VccFlags ; do
  echo "echo $VAR=\$$VAR" >> $GMKWRKDIR/gmkpack_actual_variables
done
chmod 755 $GMKWRKDIR/gmkpack_actual_variables
. $GMKWRKDIR/gmkpack_actual_variables
\rm $GMKWRKDIR/gmkpack_actual_variables
