#!/bin/bash
########################################################################
#
#    Script envvarpack
#    -----------------
#
#    Purpose : In the framework of a pack : to make the list of "export" statements 
#    -------   for environment variables used by a compilation script.
#
#    Parameters : none. 
#    ----------
#
########################################################################

export LC_ALL=C

if [ ! "$GMKFILEPATH" ] || [ ! "$FLAVOUR" ] ; then
GMK_SUPPORT=${GMK_SUPPORT:=$HOME/gpupack/gmkpack/support}
  TARGET_GMKFILE=$(\ls -1t $TARGET_PACK/.gmkfile 2>/dev/null | tail -1)
  if [ "$TARGET_GMKFILE" ] ; then
#   At the creation of a pack, the TARGET_GMKFILE would not exist :
    GMKFILEPATH=$TARGET_PACK/.gmkfile
    FLAVOUR=$(\ls -1t $GMKFILEPATH | tail -1)
  elif [ -f $HOME/.gmkpack/arch/$GMKFILE.$LIBOPT ] ; then
#   Search for a personal TARGET_GMKFILE + current options :
    GMKFILEPATH=$HOME/.gmkpack/arch
    FLAVOUR=$GMKFILE.$LIBOPT
  elif [ -f $GMK_SUPPORT/arch/$GMKFILE.$LIBOPT ] ; then
#   Search for a shared TARGET_GMKFILE + current options :
    GMKFILEPATH=$GMK_SUPPORT/arch
    FLAVOUR=$GMKFILE.$LIBOPT
  elif [ -f $HOME/.gmkpack/arch/$GMKFILE.$GMK_OPT ] ; then
#   Search for a personal TARGET_GMKFILE + default options : 
    GMKFILEPATH=$HOME/.gmkpack/arch
    FLAVOUR=$GMKFILE.$GMK_OPT
  elif [ -f $GMK_SUPPORT/arch/$GMKFILE.$GMK_OPT ] ; then
#   Search for a shared TARGET_GMKFILE + default options :
    GMKFILEPATH=$GMK_SUPPORT/arch
    FLAVOUR=$GMKFILE.$GMK_OPT
  elif [ -f $SOURCE_PACK/.gmkfile/${GMKFILE} ] ; then
#   Search for the actual GMKFILE used in source pack (no option there !):
    GMKFILEPATH=$SOURCE_PACK/.gmkfile
    FLAVOUR=$GMKFILE
  else
    echo "Error : no file ${GMKFILE}* could be found either in source pack, \$HOME/.gmkpack/arch or \$GMK_SUPPORT/arch."
    exit 1
  fi
fi

grep '^[A-Z]' $GMKFILEPATH/$FLAVOUR | grep -v "^LIBFRT = " | sed 's/= /="/1' | sed 's/$/"/1' | sed 's/="$/=""/1' | sed "s/ =/=/1" | sed "s/^/export /" > $GMKWRKDIR/gmkpack_exported_variables
while [ $(grep -c " =\"" $GMKWRKDIR/gmkpack_exported_variables) -ne 0 ] ; do
  sed 's/ ="/="/' $GMKWRKDIR/gmkpack_exported_variables > $GMKWRKDIR/gmkpack_exported_variables.new
  \mv $GMKWRKDIR/gmkpack_exported_variables.new $GMKWRKDIR/gmkpack_exported_variables
done 
# Evaluate LIBFRT:
GMKTMP=${GMKTMP:=/tmp}
grep ^LIBFRT $GMKFILEPATH/$FLAVOUR | cut -d " " -f3- > $GMKTMP/libfrt
chmod 755 $GMKTMP/libfrt
LIBFRT=$(. $GMKTMP/libfrt)
echo "export LIBFRT=$LIBFRT" >> $GMKWRKDIR/gmkpack_exported_variables

grep -v "^export GMK_NQS_" $GMKWRKDIR/gmkpack_exported_variables
\rm -f $GMKWRKDIR/gmkpack_exported_variables $GMKTMP/libfrt
