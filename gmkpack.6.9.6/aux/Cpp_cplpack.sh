#!/bin/bash
########################################################################
#
#    Script Cpp_cplpack
#    --------------
#
#    Purpose : In the framework of a pack : to compile in a local
#    -------   (ie distributed) framework C++ files
#
#    Usage : Cpp_cplpack $1 $2
#    -----
#              $1 : file list of element to compile
#              $2 : directory for compilation
#              $3 : branch name
#
#    Environment variables :
#    ---------------------
#            ICS_ECHO      : Verboose level (0 or 1 or 2 or 3)
#            ICS_INCPATH   : Paths for inclusions
#            LIST_VCCFLAGS : cc flags for listing
#            ICS_LIST      : switch for listings
#            AWK           : awk program 
#            LIST_EXTENSION: filename extension for listings
#            GMKROOT       : gmkpack root directory
#            ICS_CXX         : c++ compiler and flags
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
    FLAGS="$ICS_CXX $MyVccFlags $LIST_VCCFLAGS"
  else
    FLAGS="$ICS_CXX $MyVccFlags"
  fi
else
  FLAGS="$ICS_CXX $VccFlags"
fi

for vob in $(cut -d "/" -f1 $1 | sort -u) ; do
  VOBNAME=$(echo $vob | tr '[a-z]' '[A-Z]')
  OPTVOB=GMK_CFLAGS_${VOBNAME}
#  CplOpts="$FLAGS ${!OPTVOB}"
# "${!OPTVOB}" is for bash on some advanced ksh ; typeset -n is not supported everywhere neither
  CplOpts="$FLAGS $(env | grep "^${OPTVOB}=" | cut -d"=" -f2-)"
  for file in $(grep "^${vob}/" $1) ; do
    base=$(basename $file)
    if [ $ICS_TIMING_REPORT -gt 0 ] ; then
      ext=$(echo $base | $AWK -F"." '{print $NF}')
      TIMEFILE=$(basename $base .$ext).${GMK_TIMEFILE_EXTENSION}
      CplOpts="$GMK_TIMER -f %e:$file -o $TIMEFILE $CplOpts"
    fi
    echo "${CplOpts} ${ICS_ECHO_INCDIR} ${branch}/${file}"
    export GMK_CURRENT_FILE=$file
    \ln -s $MKTOP/$branch/$file $base
    eval $CplOpts $ICS_INCPATH $base
    \rm -f $base
#   Fetch back everything produced but filter the symbolic links and the hidden files:
    \mv $(find * -name "*" -type f -print 2>/dev/null) $MKMAIN/$(dirname $file) 2> /dev/null
  done
done
