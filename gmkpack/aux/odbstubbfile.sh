#!/bin/bash
########################################################################
#
#    Script odbstubbfile
#    --------------
#
#    Purpose : Make Static stubb file for ODB
#    -------   
#
#    Usage : odbstubfile $1
#    -----
#              $1 : file list of element to compile
#              $2 : local working directory
#              $3 : file list of rejected files
#
#    Environment variables :
#    ---------------------
#            GMK_THREADS : number threads
#            GMKWRKDIR   : main working directory
#            GMKROOT     : gmkpack root directory
#            label       : ddl name
#
########################################################################

export LC_ALL=C

echo "$(basename $ODB98NAME) $ODBFLAGS -i -s -S -w -l $label -o \$PWD \$$1"

DIR=$PWD

ddlfile=${label}.ddl_
mkdir $2
cd $2
ln -s ../${ddlfile} ${ddlfile}
for file in $(cat $DIR/$1) ; do
  ln -s ../$file $file
done

if [ $ICS_ECHO -le 2 ] ; then
  for file in $(cat $DIR/$1) ; do
    eval $ODB98NAME $ODBFLAGS -i -s -S -w -l $label -o $PWD $file 1>/dev/null
    if [ ! -f ${label}_$(basename $file sql)c ] ; then
      echo $file >> $3
    fi
  done
else
  for file in $(cat $DIR/$1) ; do
    eval $ODB98NAME $ODBFLAGS -i -s -S -w -l $label -o $PWD $file
    if [ -s $(basename $file .sql).lst ] ; then
      cat $(basename $file .sql).lst
    elif [ -f $(basename $file .sql).lst ] ; then
      echo $(basename $file .sql).lst is empty.
    else
      echo no file $(basename $file .sql).lst
    fi
    if [ ! -f ${label}_$(basename $file sql)c ] ; then
      echo $file >> $3
    fi
  done
fi

cd $DIR
