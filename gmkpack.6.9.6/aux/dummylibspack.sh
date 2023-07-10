#!/bin/bash
########################################################################
#
#    Script dummylibspack
#    --------------
#
#    Purpose : In the framework of a pack : to make archive libraries
#    -------   of dummy projects.
#
#    Usage : dummylibspack
#    -----
#
#    Environment variables :
#    ---------------------
#            MKLIB     : directory of libraries
#            MKTOP     : directory of all source files
#            GMKWRKDIR : main working directory
#            AR        : ar command
#            GMKROOT   : gmkpack root directory
#            ICS_PROJLIBS  : list of projects
#
########################################################################

export LC_ALL=C

echo
echo ------ Make/Update dummies libraries -----------------------------------
echo
#
MyTmp=$GMKWRKDIR/dummylibspack
mkdir -p $MyTmp
#
cd $MyTmp

target=$(uname -s | tr '[A-Z]' '[a-z]')
for project in $(eval echo $ICS_PROJLIBS) ; do
  if [ -s $GMKROOT/dummy/$project ] ; then
    find . -name "*" -type f -exec \rm -f {} \;
    mylib=libdummy${project}.${GMKLOCAL}.a
    for dir in $(cat $GMKROOT/dummy/$project) ; do
      if [ -d $MKTOP/$GMKLOCAL/$project/$dir ] ; then 
#       Because dir might not exist if source dir had not been fully filled
        for object in $(find $MKTOP/$GMKLOCAL/$project/$dir -name "*.o" -print) ; do
#         Create the compile files for each symbol if not already in any dummies archive lib
#         filter symbols which contain a "dot" character because they break the compilation
#         and they are not true entries
#         The same with "$" which could exist with open-mp on some machines
          for symbol in $($NMOPTS -p $object 2>/dev/null | grep " T " | grep "_$" | $AWK '{print $NF}' | grep -v ".\.." | grep -v "\\$") ; do 
            for dummylib in $(\ls -1 $MKLIB | grep ^libdummy${project} | grep "\.a$") ; do
              if [ $($NMOPTS -p $MKLIB/$dummylib 2>/dev/null | grep -c $symbol) -gt 0 ] ; then
                DUMMYLIB=1
                break
              fi
            done
            if [ "$DUMMYLIB" ] ; then
              unset DUMMYLIB
            else
#             symbols are prefixed with "." by xlf, "_" by g95/gfortran
              usersymbol=$(echo $symbol | sed "s/^\.//" | sed "s/^_//")
              file=$(basename $usersymbol _)
              echo "#include <stdio.h>" > $file.c
              echo "void ${usersymbol}() { printf(\"${file} : dummy subroutine by gmkpack\\\n\"); return; }" >> $file.c
            fi
          done
        done
      fi
    done
    find . -name "*.c" -exec touch archive_signal \; 2>/dev/null
    if [ -f archive_signal ] ; then
#     Compile and update archive
      echo "update $mylib :"
      \rm archive_signal
      find . -name "*.c" -print | xargs $VCCNAME $(eval echo $VCCFLAGS $OPT_VCCFLAGS)
      if [ "$target" = "darwin" ] ; then
        find . -name "*.o" -print | xargs $AR -cqvS $MKLIB/$mylib
        if [ -f $MKLIB/$mylib ] ; then
          ranlib -no_warning_for_no_symbols $MKLIB/$mylib
        fi
      else
        find . -name "*.o" -print | xargs $AR -cqv $MKLIB/$mylib
      fi
    elif [ -f $MKLIB/$mylib ] ; then
      echo "$mylib is up to date"
    fi
  fi
done

#
cd $GMKWRKDIR
\rm -rf dummylibspack
