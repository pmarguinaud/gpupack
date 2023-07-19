#!/bin/bash
########################################################################
#
#    Script sizepack
#    --------------
#
#    Purpose : In the framework of a pack : to sort a list of element 
#    -------   per decreasing size
#
#    Usage : sizepack $1
#    -----
#              $1 : file list of elements to sort
#              1> : sorted file list of elements
#
#    Environment variables :
#    ---------------------
#            MKTOP : directory of all source files
#            AWK   : awk program
#
########################################################################
#
export LC_ALL=C

ii=0
for element in $(cat $1) ; do
  branch=$(echo $element | cut -d"@" -f1)
  file=$(echo $element | cut -d"@" -f2)
  ii=$(($ii+1))
  name[$ii]=$element
  size[$ii]=$(\ls -l $MKTOP/$branch/$file | $AWK '{print $5}')
done
Nfile=$ii
#
AnyChange=yes
while [ "$AnyChange" ] ; do
  ii=1
  unset AnyChange
  while [ $ii -lt $Nfile ] ; do
    jj=$(($ii+1))
    if [ ${size[${ii}]} -lt ${size[${jj}]} ] ; then
      AnyChange=yes
      xsize=${size[${jj}]}
      xname=${name[${jj}]}
      size[${jj}]=${size[${ii}]}
      name[${jj}]=${name[${ii}]}
      size[${ii}]=${xsize}
      name[${ii}]=${xname}
    fi
    ii=$jj
  done
done
#
for element in ${name[*]} ; do
  echo $element
done
