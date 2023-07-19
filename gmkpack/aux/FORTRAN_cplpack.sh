#!/bin/bash
########################################################################
#
#    Script FORTRAN_cplpack
#    --------------
#
#    Purpose : In the framework of a pack : to compile in a local
#    -------   (ie distributed) framework
#
#    Usage : FORTRAN_cplpack $1 $2 $3 $4
#    -----
#              $1 : file list of element to compile
#              $2 : directory for compilation
#              $3 : branch name
#              $4 : list of directories to add to include/module path
#
#    Environment variables :
#    ---------------------
#            ICS_ECHO      : Verboose level (0 or 1 or 2 or 3)
#            ICS_INCPATH   : Paths for inclusions
#            LIST_FRTFLAGS : Fortran flags for listing
#            ICS_LIST      : switch for listings
#            AWK           : awk program 
#            LIST_EXTENSION: filename extension for listings
#            GMKROOT       : gmkpack root directory
#            ICS_NC_DIR     : directory for norms reports
#            ICS_NC_SEVERITY: norms checker severity level
#            ICS_F90_CPP    : .F90 flags
#            ICS_F90_EXP    : .f90 flags
#            ICS_F77_CPP    : .F flags
#            ICS_F77_EXP    : .f flags
#
########################################################################
#

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi
cd $2
branch=$3
if [ "$branch" = "$GMKLOCAL" ] ; then
  if [ "$ICS_LIST" = "yes" ] ; then
    OPT_F90="$ICS_F90_CPP $MyF90Flags $LIST_FRTFLAGS"
    OPT_F90_NOCPP="$ICS_F90_EXP $MyF90Flags $LIST_FRTFLAGS"
    OPT_F77="$ICS_F77_CPP $DBL_FRTFLAGS $MyF77Flags $LIST_FRTFLAGS"
    OPT_F77_NOCPP="$ICS_F77_EXP $DBL_FRTFLAGS $MyF77Flags $LIST_FRTFLAGS"
  else
    OPT_F90="$ICS_F90_CPP $MyF90Flags"
    OPT_F90_NOCPP="$ICS_F90_EXP $MyF90Flags"
    OPT_F77="$ICS_F77_CPP $DBL_FRTFLAGS $MyF77Flags"
    OPT_F77_NOCPP="$ICS_F77_EXP $DBL_FRTFLAGS $MyF77Flags"
  fi
else
  OPT_F90="$ICS_F90_CPP $F90Flags "
  OPT_F90_NOCPP="$ICS_F90_EXP $F90Flags"
  OPT_F77="$ICS_F77_CPP $DBL_FRTFLAGS $F77Flags"
  OPT_F77_NOCPP="$ICS_F77_EXP $DBL_FRTFLAGS $F77Flags"
fi

# Support for auto-generated interfaces encapsulated inside modules :
# first directory is $GMKINTFB, not the vob name itself.
# Therefore we should define precisely the list of "vob"s
VOBLIST_INTFB="$(echo $(cut -d "/" -f1-2 $1 | sort -u | grep "^${GMKINTFB}\/"))"
VOBLIST_TRUE="$(echo $(cut -d "/" -f1 $1 | sort -u | grep -v "^${GMKINTFB}"))"

for pseudo in $(eval echo $VOBLIST_INTFB $VOBLIST_TRUE) ; do
  vob=$(echo $pseudo | cut -d "/" -f2)
  unset NormsChecker
  if [ "$branch" = "$GMKLOCAL" ] ; then
    if [ $(echo $pseudo | grep -c "/") -eq 0 ] ; then
#     This is an interface block 
      Intfb=$(find $MKTOP/*/$GMKINTFB -name "[^\.]*" -type d -follow -print 2>/dev/null | awk -F "/" '{print $NF}' | sort -u | grep -c "^$vob$")
      if [ $ICS_NC_SEVERITY -gt 0 ] ; then
        NormsChecker=$(\ls -1 $GMKROOT/norms/$vob/norms_checker.sh 2>/dev/null)
      fi
    else
#     This is not an auto-generated interface block
      Intfb=0
    fi 
  else
    Intfb=0
  fi
  VOBNAME=$(echo $vob | tr '[a-z]' '[A-Z]')
  OPTVOB=GMK_FCFLAGS_${VOBNAME}
  SPECIFIC="$(env | grep "^${OPTVOB}=" | cut -d"=" -f2-)"
# The next double-nested conditional block is here until .mnh/MNH files have disappeared and GMK_FCFLAGS_{MSE,SURFEX,MPA} are set
  if [ "$VOBNAME" = "MSE" ] || [ "$VOBNAME" = "SURFEX" ] || [ "$VOBNAME" = "MPA" ] ; then
#   Implicit typing:
    if [ ! "$SPECIFIC" ] ; then
      SPECIFIC="$DBL_FRTFLAGS"
    fi
  fi
  for file in $(egrep "(^${vob}/|^${GMKINTFB}/${vob}/)" $1) ; do
    base=$(basename $file)
    ext=$(echo $base | $AWK -F"." '{print $NF}')
    dir=$(dirname $file)
    obj=$(basename $base .$ext).o
    if [ "$ext" = "F90" ] ; then
      CplOpts="$OPT_F90 $SPECIFIC"
    elif [ "$ext" = "f90" ] ; then
      CplOpts="$OPT_F90_NOCPP $SPECIFIC"
    elif [ "$ext" = "F" ] ; then
      CplOpts="$OPT_F77 $SPECIFIC"
    elif [ "$ext" = "f" ] ; then
      CplOpts="$OPT_F77_NOCPP $SPECIFIC"
    fi

    if [ "x$GMK_DR_HOOK_ALL" != "x" ] ; then
      DrhookOpts=$($GMKROOT/aux/drhook_all.pl --fflags --full-cpp-flags $file $GMK_DR_HOOK_ALL_FLAGS)
      CplOpts="$CplOpts $DrhookOpts"
      LnCmd="$GMKROOT/aux/drhook_all.pl --base-dir=$MKTOP/$branch --preprocess"
    else
      LnCmd="ln -s"
    fi

    if [ $ICS_TIMING_REPORT -gt 0 ] ; then
      TIMEFILE=$(basename $base .$ext).${GMK_TIMEFILE_EXTENSION}
      CplOpts="$GMK_TIMER -f %e:$file -o $TIMEFILE $CplOpts"
    fi

    if [ "$NormsChecker" ] || [ $Intfb -ne 0 ] ; then
      list=$(basename $obj .o).$LIST_EXTENSION
    fi
#   Compile
    echo "${CplOpts} ${ICS_ECHO_INCDIR} $branch/$file"
    export GMK_CURRENT_FILE=$file
    if [ "$ext" = "F90" ] && [ $Intfb -ne 0 ] ; then
      eval $LnCmd $MKTOP/$branch/$file $base
      $GMKROOT/intfb/$vob/wrapperF90.sh $base $list "$CplOpts $ICS_INCPATH"
    else
      eval $LnCmd $MKTOP/$branch/$file $base 
      eval $CplOpts $ICS_INCPATH $base
    fi
#   Check norms
    if [ "$NormsChecker" ] ; then
      norms=$ICS_NC_DIR/$file
      $NormsChecker $base $list $norms
    fi
    \rm -f $base $locbase

# Link modules and submodules to .include/ directory
    for ext in $MODEXT smod ; do
    for module in $(find * -name "*.$ext" -type f -print 2>/dev/null) ; do
      if [ ! -d $MKMAIN/.include/$vob/modules ] ; then
	mkdir -p $MKMAIN/.include/$vob/modules
      fi
      \ln -s -f ../../../$dir/$module $MKMAIN/.include/$vob/modules/$module
      echo "$MKMAIN/.include/$vob/modules" >> $4
    done
    done
# Fetch back everything produced but filter the symbolic links and the hidden files :
    if [ ! -d $MKMAIN/$dir ] ; then
      mkdir -p $MKMAIN/$dir
    fi
    \mv $(find * -name "*" -type f -print 2>/dev/null) $MKMAIN/$dir 2> /dev/null
  done
done
