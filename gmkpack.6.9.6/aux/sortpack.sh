#!/bin/bash
########################################################################
#
#    Script sortpack
#    --------------
#
#    Purpose : In the framework of a pack : to sort the files in a
#    -------   proper order for compilation
#
#    Usage : sortpack $1
#    -----
#               $1 : (output) descriptors for modules in compilation list
#               $2 : (output) list of all files 
#
#    Environment variables :
#    ---------------------
#            DEP       : "yes" if dependencies requested
#            MKTOP     : directory of all source files
#            GMKWRKDIR   : main working directory
#            ICS_ECHO  : Verboose level (0 or 1 or 2)
#            AWK       : awk program
#            GMKROOT   : gmkpack root directory
#            GMKVIEW   : list of all branches, from bottom to top
#
########################################################################

export LC_ALL=C

MyTmp=$GMKWRKDIR/sortpack
mkdir -p $MyTmp
find $MyTmp -name "*" -type f | xargs /bin/rm -f
cd $MyTmp

# List of all files:
# gmak.pl is able to make and sort the compilation list, even if it is huge:
if [ $(cat $TARGET_PACK/.gmkview | wc -l) -eq 1 ] || [ "$DEP" = "yes" ] ; then
  echo "Ordered compilation list INCluding dependencies ..."
  export DEPSEARCH=1
  export MKBRANCHES="$GMKVIEW"
else
  echo "Ordered compilation list EXcluding dependencies ..."
  export DEPSEARCH=0
  export MKBRANCHES=$GMKLOCAL
fi
if [ $DEPSEARCH -eq 1 ] ; then
  touch $GMAKDIR/.depsearch
else
  \rm -f $GMAKDIR/.depsearch
fi
# Select files which use nobody, to go faster:
# does not work :
export MKTMP=$MyTmp
# Input file:
\cp $GMAKDIR/${GMKLOCAL}.sds ${GMKLOCAL}.sds
$GMKROOT/aux/gmak.pl comp_list > /dev/null

$AWK '{print $2 "@" $1}' comp_list > comp_list.deps
cat comp_list.deps 1> $2 2>/dev/null

# Sources view: 
if [ $(cat $TARGET_PACK/.gmkview | wc -l) -eq 1 ] ; then
  echo "Source descriptors for local view is trivial ..."
  cd $GMAKDIR
  \rm -f view
  \ln -s local.sds view
  cd $MyTmp
else
  echo "Compute source descriptors for local view ..."
  $GMKROOT/aux/Pviewpack.sh $2 $GMAKDIR/view
fi

# Modules view:
echo Local view for modules ...
fgrep GMKNAME $GMAKDIR/view > $1

# Check for duplicated modules :
echo Check for duplicated modules ...
unset ERR
cut -d";" -f4 $1 | cut -d"'" -f2 | sort > modules
sort -u modules > modules.unique
comm -23 modules modules.unique > modules.dupli
if [ -s modules.dupli ] ; then
  echo WARNING ! Duplicated modules detected :
  for module in $(cat modules.dupli) ; do
    echo module $module in :
    grep "GMKNAME{'$module'} =" $1 | cut -d";" -f4| cut -d"'" -f4 > clones_list
    ref=$(head -1 clones_list)
    clone1=$(grep $ref $1 | $AWK -F"'" '{print $8}')/${ref}
    unset TEST
    for clone in $(cat clones_list) ; do
      clonex=$(grep $clone $1 | $AWK -F"'" '{print $8}')/${clone}
      echo $clonex
      cmp -s $MKTOP/$clone1 $MKTOP/$clonex
      if [ $? -ne 0 ] ; then
        TEST=1
      fi
    done
    if [ "$TEST" ] ; then
#     Modules contents are actually different.
#     However, if the module is used by the source file itself,
#     and no other files use this module,
#     In other words : each module is private to its own file, then
#     we can go on :
#     List of files using this module :
      grep "'${module}\.${MODEXT}'" $1 | cut -d"'" -f2 | sort -u > module_users
#     List of clones of this module :
      grep "GMKNAME{'${module}'}" $1 | cut -d"'" -f2 | sort -u > module_clones
      cmp -s module_users module_clones
      if [ $? -ne 0 ] ; then
        ERR=1
        echo Fatal error : multiple modules conflict !
      else
        echo Each module is private to its own file, going on ... 
      fi
    else
      echo Modules source code is identical, going on ...
    fi
  done
fi
if [ "$ERR" ] ; then
  cd $GMKWRKDIR
  \rm -rf sortpack 
  echo Abort job.
  exit 1
fi

echo Split compilation list for parallel work ...
$GMKROOT/aux/splitpack.pl $MyTmp/comp_list.deps $MyTmp/ics_lists.tar
\mv $MyTmp/ics_lists.tar $GMAKDIR/ics_list.tar

cd $GMKWRKDIR
\rm -rf sortpack
