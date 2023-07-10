#!/bin/bash
########################################################################
#
#    Script cplpack
#    --------------
#
#    Purpose : In the framework of a pack : to compile in a local
#    -------   (ie distributed) framework
#
#    Usage : cplpack $1 $2
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
#            ICS_CC         : .c flags
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
    FLAGS="$ICS_CC $MyVccFlags $LIST_VCCFLAGS"
  else
    FLAGS="$ICS_CC $MyVccFlags"
  fi
else
  FLAGS="$ICS_CC $VccFlags"
fi
PRECOMPILER="$(basename $ODB98NAME) $ODBFLAGS -w -l"

for vob in $(cut -d "/" -f1 $1 | sort -u) ; do
  VOBNAME=$(echo $vob | tr '[a-z]' '[A-Z]')
  OPTVOB=GMK_CFLAGS_${VOBNAME}
#  CplOpts="$FLAGS ${!OPTVOB}"
# "${!OPTVOB}" is for bash on some advanced ksh ; typeset -n is not supported everywhere neither
  MORE_ODB_FLAGS="$(env | grep "^${OPTVOB}=" | cut -d"=" -f2-)"
# Because I don't know really which flag may be use and which ones would never be used inside odb98,
# and because odb98 has several options, let's select only the macros (-D or -U).
  FILTERED_ODB_MACROS="$(echo $(echo $MACROS_CC $MORE_ODB_FLAGS | tr " " "\n" | egrep "(^-D|^-U)"))"
  if [ $ICS_ECHO -le 2 ] ; then
    ODBCplOpts="$ODB98NAME $ODBFLAGS $FILTERED_ODB_MACROS -w -l"
  else
    ODBCplOpts="$ODB98NAME $ODBFLAGS $FILTERED_ODB_MACROS -V -w -l"
  fi
  CplOpts="$FLAGS $MACROS_CC $MORE_ODB_FLAGS"
  for file in $(grep "^${vob}/" $1) ; do
    base=$(basename $file)
    dir=$(dirname $file)
#   ddl base MUST be identified to get the proper object name:
#   odb/ddl.${BASE}/request.sql => odb/ddl.${BASE}/${BASE}_request.o
    label=$(echo $(basename $dir)| sed "s/^ddl\.//")
    obj=${label}_$(basename $base .sql).o
    list=$(basename $obj .o).$LIST_EXTENSION
    echo "$PRECOMPILER $label || ${CplOpts} ${ICS_ECHO_INCDIR} ${branch}/${file}"
    export GMK_CURRENT_FILE=$file
    \ln -s $MKTOP/$branch/$file $base
#   Precompile:
    ddl_file=$(find $MKTOP/*/$dir -name "${label}.ddl_" | xargs \ls -1t | head -1)
    \ln -s $ddl_file $(basename $ddl_file)
#   Search the latest compilation flags in the current database
#   should rather be a search in gmkview (orderded)
    export ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/$dir/odb98.flags 2>/dev/null | head -1)
    if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#     Else, search the latest compilation flags in the general ddl directory
      export ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/ddl/odb98.flags 2>/dev/null | head -1)
      if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#       Else, give a chance to any exotic directory :-(
        export ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/*/odb98.flags 2>/dev/null | head -1)
      fi
    fi
    eval $ODBCplOpts $label $base
#   Hard-code in odb98 with extension "lst":
    if [ -f *.lst ] ; then
      \mv *.lst 1> $list 2>/dev/null
    fi
    if [ "$ICS_LIST" = "no" ] ; then
      cat $list 2>/dev/null
      \rm -f $list
    fi
    \rm -f *.ddl_ $base
    locbase=$(basename $obj .o).c
    if [ -f $locbase ] ; then
      if [ $ICS_TIMING_REPORT -gt 0 ] ; then
        TIMEFILE=$(basename $locbase .c).${GMK_TIMEFILE_EXTENSION}
        CplOpts="$GMK_TIMER -f %e:$locbase -o $TIMEFILE $CplOpts"
      fi

# Save sql requests precompiled in C :
#      if [ ! -d $MKMAIN/.sql_requests ] ; then
#        mkdir $MKMAIN/.sql_requests
#      fi
#      /bin/cp $locbase $MKMAIN/.sql_requests/

#     Compile:
      eval $CplOpts $ICS_INCPATH $locbase
      \rm -f $locbase
#     Fetch back everything produced but filter the symbolic links and the hideen files
      \mv $(find * -name "*" -type f -print 2>/dev/null) $MKMAIN/$dir 2> /dev/null
    fi
  done
done

