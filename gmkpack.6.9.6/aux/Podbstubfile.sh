#!/bin/bash
########################################################################
#
#    Script Podbstubbfile
#    --------------
#
#    Purpose : In the framework of a pack : distribute compilation then
#    -------   submit distributed compilation
#
#    Usage : Podbstubfile
#    -----
#
#    Environment variables :
#    ---------------------
#            GMK_THREADS : number threads
#            GMKWRKDIR   : main working directory
#            GMKROOT     : gmkpack root directory
#            SSTUBBFILENAME  : static stubb filename
#            label       : ddl name
#
########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

DIR=$PWD
Dirwork=dirwork

List=list_of_sql_files
Rejected=list_of_rejected_sql
#each task will perform a chunk ; the partial stubb files are cleverly concatenated.
# list of files :
find * -name "*.sql" > $List 

if [ -s $List ] ; then

# Submit parallel compilation (first job has rank 0):
  $GMKROOT/aux/mpsh_driver.sh $GMKROOT/aux/odbstubbfile.sh $List $Dirwork $Rejected

# Concatenate stubb files :
# head :
  sed "/ODB_ANCHOR_VIEW/,$ d" ${Dirwork}.0/$SSTUBBFILENAME > $DIR/$SSTUBBFILENAME
# body : sort in reverse order, as it looks to be computed in odb98.x
  find ${Dirwork}.* -name "$SSTUBBFILENAME" | xargs grep -h "ODB_ANCHOR_VIEW" | sort -r >> $DIR/$SSTUBBFILENAME
# tail :
  sed "1,/ODB_ANCHOR_VIEW/ d" ${Dirwork}.0/$SSTUBBFILENAME | grep -v "ODB_ANCHOR_VIEW" >> $DIR/$SSTUBBFILENAME

# List .sql files not in static stubb file (for which C code could not be generated) :
  cat ${Rejected}.* > $REJECTED_SQL 2>/dev/null

  /bin/rm -rf ${Dirwork}.* ${List}.*

fi
