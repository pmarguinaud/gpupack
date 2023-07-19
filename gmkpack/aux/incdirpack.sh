#!/bin/bash
########################################################################
#
#    Script incdirpack
#    ----------------
#
#    Purpose : In the framework of a pack : to build the list of include pathes
#    -------
#
#    Usage : incdirpack.sh
#    -----
#
#    Environment variables :
#    ---------------------
#             MKTOP : all source code directory
#             INCDIR_LIST : file list of include directories
#
########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

# First user include pathes :
# 1/list of all dirs containing include files:
# Current include directories (additionning the ghostpath in between) :
#cat $MKTOP/.modpath.local $MKTOP/.incpath.local $MKTOP/.ghostpath.local $MKTOP/.modpath $MKTOP/.incpath $MKTOP/.ghostpath \
# No : the ghostpath should prevail over background module path, since they have been discovered during recompilation :
cat $MKTOP/.ghostpath.local $MKTOP/.modpath.local $MKTOP/.incpath.local  $MKTOP/.ghostpath $MKTOP/.modpath $MKTOP/.incpath \
  2>/dev/null | sed "s/^$MODINC//g" > $INCDIR_LIST
# Add unsatisfied externals directory if relevent :
for uxdir in ${GMKUNSX_QUIET} ${GMKUNSX_VERBOOSE} ; do
  absdir=${MKTOP}/${GMKUNSX}/$uxdir
  if [ $(\ls -1 $absdir | grep -c "\.h$") -ne 0 ] ; then
    echo $absdir >> $INCDIR_LIST
  fi
done

# Then module directories in hub (from top to bottom branch) :
if [ -s $TARGET_PACK/$GMK_HUB_DIR/$GMK_VIEW ] ; then
  for project in $(echo $GMK_HUB_PROJECTS) ; do
    for branch in $(echo $(cat $TARGET_PACK/$GMK_HUB_DIR/$GMK_VIEW)) ; do
      if [ -d $TARGET_PACK/$GMK_HUB_DIR/$branch/$GMK_HUB_INSTALL/$project ] ; then
        find $TARGET_PACK/$GMK_HUB_DIR/$branch/$GMK_HUB_INSTALL/$project -name "*.mod" -type f -follow -exec dirname {} \; \
        | sort -u >> $INCDIR_LIST
        cd $TARGET_PACK/$GMK_HUB_DIR/$branch/$GMK_HUB_INSTALL
#       For headers a depth down to 1 subdirectory is used, should be enough 
        for DEPTH in 0 1 ; do
          word=$((DEPTH+2))
          find $project -name "*.h" -type f -follow -exec dirname {} \; \
          | cut -d "/" -f-$word | sort -u | sed "s:^:$TARGET_PACK/$GMK_HUB_DIR/$branch/$GMK_HUB_INSTALL/:" >> $INCDIR_LIST
        done
        cd $OLDPWD
	break
      fi
    done
  done
fi

# Finally external include pathes :
if [ "$INCLUDEPATH" ] ; then
  for path in $(echo $INCLUDEPATH | sed "s/:/ /g") ; do
    echo $path >> $INCDIR_LIST
  done
fi

cd $GMKWRKDIR
/bin/rm -rf incdirpack
exit 0
