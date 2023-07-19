#!/bin/bash

# mpsh driver

#   First argument is the script to execute
#   next MPSH_DRV_INPUT_ARGUMENTS argument are common to all jobs
#   Last arguments are specific to each job

#   Second argument is the list to distribute in jobs

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

LIST=$2
# number of files :
NN=$(cat $LIST | wc -l)

# Number of threads :
if [ ! "$GMK_THREADS" ] ; then
  GMK_THREADS=1
fi
export MPSH_NPES=$GMK_THREADS

# Maximum number of jobs per thread :
if [ ! "$GMK_JOBS_PER_THREADS" ] ; then
  GMK_JOBS_PER_THREADS=1
fi

# Maximum number of jobs :
if [ ! "$GMK_MAX_JOBS" ] ; then
# limit imposed by mpsh
  GMK_MAX_JOBS=10000
fi

# Number of jobs :
MPSH_JOBS=$((GMK_THREADS*GMK_JOBS_PER_THREADS))
if [ $MPSH_JOBS -gt $GMK_MAX_JOBS ] ; then
  MPSH_JOBS=$GMK_MAX_JOBS
fi
if [ $NN -lt $MPSH_JOBS ] ; then
  MPSH_JOBS=$NN
fi
export MPSH_JOBS

if [ ! "$MPSH_DRV_INPUT_ARGUMENTS" ] ; then
  MPSH_DRV_INPUT_ARGUMENTS=1
fi
unset MyCommand
flag=0
for arg in $* ; do
  if [ $flag -eq 0 ] ; then
    MyCommand="$arg"
  elif [ $flag -eq 1 ] ; then
    MyCommand="$MyCommand ${arg}.\$ipe"
  elif  [ $flag -le $MPSH_DRV_INPUT_ARGUMENTS ] ; then
    MyCommand="$MyCommand ${arg}"
  else
    MyCommand="$MyCommand ${arg}.\$ipe"
  fi
  flag=$((flag+1))
done

# Shuffle and circular distribution of files among jobs :
grep "\.cpp$" $LIST > list_cpp  
grep "\.sql$" $LIST > list_sql 
egrep "(\.F90$|\.f90$|\.F$|\.f$)" $LIST > list_frt
grep "\.c$" $LIST > list_c 
grep "\.h$" $LIST > list_h 
egrep -v "(\.F90$|\.f90$|\.F$|\.f$|\.cpp$|\.c$|\.h$|\.sql$)" $LIST > list_others
job=0
/bin/rm -f ${LIST}.*
for file in $(cat list_cpp list_sql list_frt list_c list_h list_others) ; do
  job=$((job+1))
  if [ $job -gt $MPSH_JOBS ] ; then
    job=1
  fi
  irank=$((job-1))
  echo $file >> ${LIST}.$irank
done

# Make jobs :
job=1
while [ $job -le $MPSH_JOBS ] ; do
  irank=$((job-1))
  if [ $irank -le 9 ] ; then
    section=000$irank
  elif [ $irank -le 99 ] ; then
    section=00$irank
  elif [ $irank -le 999 ] ; then
    section=0$irank
  elif [ $irank -le 9999 ] ; then
    section=$irank
  else
    echo mpsh_driver : too much jobs.
    exit 1
  fi
# As peid does not exist on all machines:
  echo "export MPSH_PEID=$irank" > mpsh.job.$section
  echo $(echo $MyCommand | sed "s/\$ipe/$irank/g") >> mpsh.job.$section
  chmod +x mpsh.job.$section
  job=$((job+1))
done

# Invoke mpsh: 
# -----------
#echo MPSH_NPES=$MPSH_NPES
#echo MPSH_JOBS=$MPSH_JOBS
#job=1
#while [ $job -le $MPSH_JOBS ] ; do
  #irank=$((job-1))
  #echo "job=$job files=$(cat ${LIST}.$irank | wc -l)"
  #job=$((job+1))
#done

$GMKROOT/mpsh/bin/mpsh 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo error with mpsh
  exit 1
fi
exit 0
