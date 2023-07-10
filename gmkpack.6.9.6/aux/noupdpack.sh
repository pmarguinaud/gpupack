#!/bin/bash
########################################################################
#
#    Script noupdpack
#    --------------
#
#    Purpose : In the framework of a pack : not to update pack content
#    -------   before compiling, but just get the list to compile.
#
#    Usage : noupdpack $1 $2 $3
#    -----
#            $1 : (input) file containing the list of elements to update
#            $2 : (output) restricted list of element to compile
#            $3 : (output) restricted list of local object file to get
#
#    Environment variables :
#    ---------------------
#            ICS_ECHO : Verboose level (0 or 1 or 2)
#            MKMAIN   : directory of local source files
#            AWK      : awk program
#            GMKROOT  : gmkpack root directory
#
########################################################################
#
export LC_ALL=C

echo No recursive update:

WORKING_DIR=$PWD
\rm -f input_list excluded.loc input_list.tmp exclude_list ok_list $2 $3

# Select files : this block is useful because ignored files could be dependencies
if [ -s $GMKWRKDIR/.ignored_files ] ; then
  sort -u $GMKWRKDIR/.ignored_files > exclude_list
  cat $1 | cut -d "@" -f2 | sort -u > input_list
  comm -12 input_list exclude_list > excluded.loc
  if [ -s excluded.loc ] ; then
    comm -13 input_list exclude_list | sed "s/^/Not compiled : /"
    cp $1 input_list.tmp
    for file in $(cat excluded.loc) ; do
      grep -v "@${file}$" input_list.tmp >  input_list.loc
      \mv input_list.loc input_list.tmp
    done
    \mv input_list.tmp input_list.loc
  else
    \cp $1 input_list.loc
  fi
  \rm -f excluded.loc exclude_list
else
  \cp $1 input_list.loc
fi

# Select & treat headers: - skip auto-generated interfaces and make relative links to .include directory:
egrep "(\.h$|\.inc$)" input_list.loc | sed -e "s/h$/ok/" -e "s/inc$/ok/" | cut -d "@" -f2 > ok_list
if [ -s ok_list ] ; then
  cd $MKMAIN
  split $WORKING_DIR/ok_list $WORKING_DIR/ok_list_split
  for file in $WORKING_DIR/ok_list_split* ; do
    touch $(cat $file)
  done
  for vob in $STDLIST ; do
    for file in $(cut -d "@" -f2 $WORKING_DIR/input_list.loc | egrep "(^${vob}.*\.h$|^${vob}.*\.inc$)") ; do
      \ln -s -f ../../../$file .include/$(echo $file | cut -d "/" -f1)/headers/$(basename $file)
    done
  done
  for vob in $(eval echo $INTFB_ALL_LIST) ; do
  for file in $(cut -d "@" -f2 $WORKING_DIR/input_list.loc | egrep "(^${vob}.*\.h$|^${vob}.*\.inc$)" | grep -v "\.intfb\.h$") ; do
      \ln -s -f ../../../$file .include/$(echo $file | cut -d "/" -f1)/headers/$(basename $file)
    done
  done
  cd $WORKING_DIR
# Verbose:
  if [ $ICS_ECHO -gt 1 ] ; then
    sed "s/^/touched : /g" ok_list
  else
    grep -v "\.intfb\.h$" ok_list | sed "s/^/touched : /"
  fi
fi

# Select compilable elements :
egrep "(\.f$|\.F$|\.f90$|\.F90$|\.c$|\.cpp$|\.cc$|\.sql$)" input_list.loc > $2


# Make objects list:
# Fortran and C/C++ files:
grep -v "\.sql$" $2 | cut -d "@" -f2 | sed -e "s/f$/o/g" -e "s/F$/o/g" -e "s/f90$/o/g" -e "s/F90$/o/g" -e "s/\.c$/.o/g" -e "s/cpp$/o/g"  -e "s/cc$/o/g" > $3
# sql requests : file Base MUST be identified to get the proper object name:
# odb/ddl.${BASE}/request.sql => odb/ddl.${BASE}/${BASE}_request.o
grep "\.sql$" $2 | cut -d "@" -f2 | sed -e "s/sql$/o/" -e "s/\/ddl\.\(.*\)\//\/ddl\.\1\/\1_/" >> $3

if [ -s $3 ] ; then
# Remove this potentially very long list of files:
  cd $MKMAIN
  perl -ne 'chomp; unlink($_)' $3
  cd $WORKING_DIR
fi
