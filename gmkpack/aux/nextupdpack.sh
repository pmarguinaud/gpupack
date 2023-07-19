#!/bin/bash
########################################################################
#
#    Script updpack
#    --------------
#
#    Purpose : In the framework of a pack : to remove direct dependencies of a
#    -------   list of modules
#
#    Usage : updpack $1 $2
#    -----
#            $1 : (input) file containing the current list of modules to update
#            $2 : (output) file containing the next list of modules to update
#
#    Environment variables :
#    ---------------------
#            N0              : position of the native module in the list of all dependencies
#            AWK             : awk program
#            ALL_FILES_LIST  : list of all files
#            ALL_DESCRIPTORS : descriptors for all modules in compilation list
#            MODEXT          : modules name extension
#
########################################################################
#
export LC_ALL=C

/bin/rm -f $2
for file in $(cat $1) ; do
  base=$(basename $file)
  dir=$(dirname $file)
  ext=$(echo $base | $AWK -F"." '{print $NF}')
  rad=$(basename $base .${ext})
  N1=$(grep -nh "@${dir}/${rad}\.${ext}" $ALL_FILES_LIST | cut -d":" -f1)
  if [ $N1 -gt $N0 ] ; then
    mod=$(grep "${dir}/${rad}\.${ext}" $ALL_DESCRIPTORS | $AWK -F"'" '{print $4}')
    if [ "$mod" ] ; then
      grep "${mod}\.${MODEXT}" $GMAKDIR/view | sed "s/[ ]*=.*$//" | cut -d"'" -f2 >> $2
     # echo " USERS OF $mod :"
     # grep "${mod}\.${MODEXT}" $GMAKDIR/view | sed "s/[ ]*=.*$//" | cut -d"'" -f2
    fi
  fi
done

