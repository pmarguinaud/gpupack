#!/bin/bash
########################################################################
#
#    Script icspack
#    --------------
#
#    Purpose : In the framework of a pack : to manage compilation
#    -------  
#
#    Usage : icspack $1
#    -----
#               $1 : (input) descriptors for all modules in compilation list
#               $2 : (input) list of all files (main flow)
#
#    Environment variables :
#    ---------------------
#            GMKWRKDIR      : main working directory
#            MKTOP          : directory of all source files
#            ICS_ERROR      : error file
#            LIST_EXTENSION : filename extension for listings
#            GMKROOT        : gmkpack root directory
#            MODINC         : compiler directive for include files
#            ICS_LIST
#            ICS_NC_DIR     : directory for norms reports
#            ICS_NC_SEVERITY: norms checker severity level
#            ICS_NC_SUPPRESS: suppressed messages from norms checker
#
########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

MyTmp=$GMKWRKDIR/icspack
mkdir -p $MyTmp
find $MyTmp -name "*" -type f | xargs /bin/rm -f
cd $MyTmp

tar xf $GMAKDIR/ics_list.tar
imax=$(\ls -1 ics_list.* | wc -l)
if [ $ICS_ECHO -gt 0 ] ; then
  i=1
  while [ -f ics_list.$i ] ; do
    echo ------ Level $i
    cat ics_list.$i
    i=$((i+1))
  done
  echo ------ End of list
fi

ii=1
istop=$imax
if [ "$ICS_ICFMODE" = "incr" ] ; then
  if [ "$ICS_START" ] ; then
    if [ $ICS_START -gt 0 ] ; then
      ii=$ICS_START
    elif [ $ICS_START -eq 0 ] ; then
      ii=0 
    fi
  elif [ -f $GMAKDIR/istart ] ; then
    ii=$(cat $GMAKDIR/istart)
  fi
  if [ "$ICS_STOP" ] ; then
    if [ $ICS_STOP -gt 0 ] ; then
      istop=$ICS_STOP
    elif [ $ICS_STOP -eq 0 ] ; then 
      istop=0
    fi
  fi
fi
ICS_START=$ii
ICS_STOP=$istop

if [ $ICS_START -eq 0 ] && [ $ICS_STOP -eq 0 ] ; then
  cd $GMKWRKDIR
  \rm -rf icspack
  exit 0
elif [ $ICS_START -gt $ICS_STOP ] ; then
  cd $GMKWRKDIR
  \rm -rf icspack
  exit 0
fi

if [ -s $GMKWRKDIR/.reduced_starting_list ] ; then
# remove "local@" ahead for continuity with older version ; add "local@" ahead.
  sed "s/^${GMKLOCAL}@//" $GMKWRKDIR/.reduced_starting_list | sort -u | sed "s/^/${GMKLOCAL}@/" > reduced_starting_list
  sort -u ics_list.$ICS_START > starting_list
  comm -12 reduced_starting_list starting_list > new_ics_list
  if [ -s new_ics_list ] ; then
    echo Reduced starting list :
    cat new_ics_list
    echo
    \mv new_ics_list ics_list.$ICS_START
  else
    comm -3 reduced_starting_list starting_list
    echo Reduced starting list is empty !
    touch $ICS_ERROR
    exit 1
  fi
fi
  
echo
echo ------ Start compilation --------------------------------------

\rm -f errorlog

\rm -f intfbvob_list
for vob in $(eval echo $INTFB_ALL_LIST) ; do
  echo $vob >> intfbvob_list
done
if [ ! -s intfbvob_list ] ; then
  unset INTFB_ALL_LIST
fi
if [ "$INTFB_ALL_LIST" ] ; then
  echo
  echo "Prepare for auto-generated interfaces for projects: $INTFB_ALL_LIST"
  echo
  for vob in $(eval echo $INTFB_ALL_LIST) ; do
    \mkdir -p $MKMAIN/.intfb/$vob
  done
  sort intfbvob_list > intfblist
  \rm -f intfbvob_list
  for vob in $ICS_PRJS ; do
    echo $vob >> vob_list
  done
  sort vob_list >  allvoblist
  \rm -f vob_list
  export STDLIST="$(echo $(comm -23 allvoblist intfblist))"
  \rm -f allvoblist intfblist
else
  export STDLIST="$ICS_PRJS"
fi

if [ $ICS_NC_SEVERITY -gt 0 ] ; then
  echo
  echo "Prepare for norms report "
  echo
  export ICS_NC_DIR=$MyTmp/norms_report
  mkdir $ICS_NC_DIR
  for dir in $(cat $MKTOP/.srcpath) ; do
    mkdir -p $ICS_NC_DIR/$dir
  done
  export SUPRESS_MESSAGE="$ICS_NC_SUPPRESS"
# Warning ckecks :
  export WCHECK_OFF=0
# Information ckecks :
  if [ $ICS_NC_SEVERITY -gt 1 ] ; then
    export ICHECK_OFF=0
  else
    export ICHECK_OFF=1
  fi
else  
  unset SUPRESS_MESSAGE
  export ICHECK_OFF=1
  export WCHECK_OFF=1
fi

# 2/set environment variables:
export ODB_SETUP_SHELL=$SHELL
export ICS_F90_CPP="$FRTNAME $FRTFLAGS $FREE_FRTFLAG $F90_CPPFLAG $MACROS_FRT"
export ICS_F90_EXP="$FRTNAME $FRTFLAGS $FREE_FRTFLAG $F90_NOCPPFLAG"
export ICS_F77_CPP="$FRTNAME $FRTFLAGS $FIXED_FRTFLAG $F77_CPPFLAG $MACROS_FRT"
export ICS_F77_EXP="$FRTNAME $FRTFLAGS $FIXED_FRTFLAG $F77_NOCPPFLAG"
export ICS_CC="$VCCNAME $VCCFLAGS $MACROS_CC"
if [ "$CXXNAME" ] ; then
  export ICS_CXX="$CXXNAME $VCCFLAGS $MACROS_CXX"
else
  export ICS_CXX="$ICS_CC"
fi

if [ "$CCUNAME" ] ; then
  export ICS_CCU="$CCUNAME $CCUFLAGS $MACROS_CCU"
else
  export ICS_CCU=""
fi

while [ ! -f $ICS_ERROR ] && [ $ii -le $ICS_STOP ] && [ $ii -le $imax ] ; do

#
  echo $ii > $GMAKDIR/istart
  echo ----------- Level $ii / $imax ---------------------------------------
#

  if [ "$ICS_RECURSIVE_UPDATE" != "no" ] ; then
#   Parallel update of elements
    $GMKROOT/aux/Pupdpack.sh $MyTmp/ics_list.$ii $MyTmp/compile $MyTmp/objects.list.$ii $1 $2
  else
#   No update : compile everything
    $GMKROOT/aux/noupdpack.sh $MyTmp/ics_list.$ii $MyTmp/compile $MyTmp/objects.list.$ii
  fi
#
# Parallel compilation
  $GMKROOT/aux/Pcplpack.sh $MyTmp/compile $MyTmp/added_incdir

  if [ -s $MyTmp/added_incdir ] ; then
    sort -u $MyTmp/added_incdir > $MyTmp/added_incdir.su
    sort -u $INCDIR_LIST > $MyTmp/existing_incdir.su
    comm -23 $MyTmp/added_incdir.su $MyTmp/existing_incdir.su > $MyTmp/added_incdir
    if [ -s $MyTmp/added_incdir ] ; then
      cat $MyTmp/added_incdir $INCDIR_LIST > $MyTmp/new_incdir
      /bin/mv $MyTmp/new_incdir $INCDIR_LIST
      echo ---------------------------------------------------------------------
      echo ---------- Added include directories :
      cat $MyTmp/added_incdir
#     The added include directories must also be saved among the pack metadata files
#     and they should not be destroyed at each recompilation (only if cleanpack/resetpack) : 
#     these are ghost directories, existing because the dependency research is not (yet) fully recursive ...
      cat $MyTmp/added_incdir | sed "s/^/$MODINC/" >> $MKTOP/.ghostpath.local
      echo ---------------------------------------------------------------------
      /bin/rm $MyTmp/added_incdir $MyTmp/added_incdir.su $MyTmp/existing_incdir.su
    fi
  fi
#
  \rm -f errorlog.$ii
  for file in $(cat objects.list.$ii 2>/dev/null) ; do
    if [ ! -f $MKMAIN/$file ] ; then
      listing=$(echo $MKMAIN/$file | sed "s/o$/$LIST_EXTENSION/")
      if [ -f $listing ] ; then
        echo $listing >> errorlog.$ii
      else
#       Research the source file in the local branch (most common case)
        unknown_filename=$(\ls -1t $(dirname $MKMAIN/$file)/$(basename $file o)* 2>/dev/null | egrep "(\.F90$|\.f90$|\.F$|\.f$|\.c$|\.cpp$|\.cc$|\.sql$)" | head -1)
        if [ "$unknown_filename" = "" ] ; then
#         Research the source file in all branches and choose the most recent one
          unknown_filename=$(\ls -1t $(echo $(dirname $MKMAIN/$file)/$(basename $file o) 2>/dev/null | sed "s/\/${GMKLOCAL}\//\/\*\//")* | egrep "(\.F90$|\.f90$|\.F$|\.f$|\.c$|\.cpp$|\.cc$|\.sql|\.cu$)" | head -1)
        fi
        if [ "$unknown_filename" ] ; then
          if [ -f $unknown_filename ] ; then
            echo $unknown_filename >> errorlog.$ii
          else
            echo file ?? from object $file >> errorlog.$ii
          fi
        else
          echo file ?? from object $file >> errorlog.$ii
        fi
      fi
      if [ "$ICS_POSTPONE_ABORT" != "yes" ] ; then
        touch $ICS_ERROR
      fi
    fi
  done
  if [ -s errorlog.$ii ] ; then
    if [ "$ICS_LIST" = "yes" ] ; then
      echo COMPILATION ERROR\(S\) REPORTED AT LEVEL $ii IN : >> errorlog
    else
      echo COMPILATION ERROR\(S\) REPORTED AT LEVEL $ii FOR : >> errorlog
    fi
    cat errorlog.$ii >> errorlog
  fi
  \rm -f errorlog.$ii
  ii=$((ii+1))
done

if [ -s errorlog ] ; then
  touch $ICS_ERROR
fi

echo ------ End compilation ----------------------------------------
echo

\rm -f recompiled_objects
find . -name "objects.list.*" -print | xargs cat >> recompiled_objects

if [ -s recompiled_objects ] && [ $ICS_NC_SEVERITY -gt 0 ] ; then
  echo ------ Norms checker report -----------------------------------
  cd $ICS_NC_DIR
  icount=0
  if [ "$GMK_NORMS_CHECKER" != "2003" ] ; then
    echo
    for file in $(find . -type f -name "*" -print) ; do
      if [ $(cat $file | wc -l) -gt 1 ] ; then
        sed "1,3 d" $file
        icount=$((icount+1))
      fi
    done
  else
    for file in $(find . -type f -name "*" -print) ; do
      if [ $(cat $file | wc -l) -gt 1 ] ; then
        echo $file :
        sed "1 d" $file
        icount=$((icount+1))
      fi
    done
  fi
  if [ $icount -eq 0 ] ; then
    echo
    echo Report empty.
  fi
  cd $MyTmp
fi

if [ "$ICS_TIMING_REPORT" ] ; then
  if [ -s recompiled_objects ] && [ $ICS_TIMING_REPORT -gt 0 ] ; then
    echo
    echo ------ Compilation timing report -----------------------------------
    cd $TARGET_PACK
    $GMKROOT/util/timepack -n$ICS_TIMING_REPORT
    cd $MyTmp
    echo --------------------------------------------------------------------
  fi
fi

echo
# Remove related libraries, libraries "below" and binaries using any of the removed libraries:
if [ -s recompiled_objects ] ; then
# Select related projects:
  i=$ICS_START
  \rm -f projlist unsafe_projlist
# In case of a new project, unsafe_projlist should exist to avoid an error message later:
  touch unsafe_projlist
  while [ $i -lt $ii ] ; do
    cat ics_list.$i 2>/dev/null | cut -d"/" -f1 | cut -d "@" -f2 | sort -u >> projlist
    i=$((i+1))
  done
  sort -u projlist > projlist.su
# Add projects "below" :
  target=$(uname -s | tr '[A-Z]' '[a-z]')
  for myprj in $(cat projlist.su 2>/dev/null) ; do
    unset UNSAFE
    for prj in $ICS_PRJS ; do
      if [ "$myprj" = "$prj" ] || [ "$UNSAFE" ] ; then
        UNSAFE="$UNSAFE $myprj"
      fi
    done
    for prj in $UNSAFE ; do
      echo $prj >> unsafe_projlist
    done
  done
  for prj in $(sort -u unsafe_projlist) ; do
    for lib in $(\ls $MKLIB/lib*${prj}.${GMKLOCAL}.a 2> /dev/null) ; do
      if [ -f $lib ] ; then 
        echo Remove library $(basename $lib)
        \rm -f $lib
      fi
    done
    for binary in $(\ls -a $GMKWRKDIR 2> /dev/null | grep ^[.] | grep _link$ | cut -d"." -f2- | sed "s/_link$//") ; do
      if [ -s $GMKWRKDIR/.${binary}_link ] ; then
        executable=$(grep EXEC $GMKWRKDIR/.${binary}_link | cut -d"=" -f2)
        if [ "$executable" ] ; then
          sharelib=$(echo $executable | $AWK -F "." '{print $NF}')
          if [ "$target" = "darwin" ] && [ "$sharelib" = "so" ] ; then
            loadmodule=$MKLINK/$(basename $executable .so).dylib
          else
            loadmodule=$MKLINK/$executable
          fi
          if [ -f $loadmodule ] ; then
            if [ $(cat $GMKROOT/link/$binary/projlist \
                       $GMK_SUPPORT/link/$binary/projlist \
                       $HOME/.gmkpack/link/$binary/projlist \
                       2>/dev/null | grep -c ^$prj$) -ne 0 ] ; then
              echo Remove executable $loadmodule
             \rm -f $loadmodule
            fi 
          fi 
        fi 
      fi 
    done
  done
else
  echo No \(re-\)compilations.
fi
\rm -f recompiled_objects
#
if [ -f $ICS_ERROR ] ; then
  cat errorlog
fi
cd $GMKWRKDIR
\rm -rf icspack
if [ -f $ICS_ERROR ] ; then
  echo
  exit 1
fi
