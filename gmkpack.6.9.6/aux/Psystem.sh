#!/bin/bash

# A quick&dirty wrapper for mpsh.

# Generic command:
# ---------------

export LC_ALL=C

unset MyCommand
flag=0
for arg in $* ; do
  if [ $flag -eq 0 ] ; then
    MyCommand="$arg"
    flag=1
  else
    MyCommand="$MyCommand ${arg}.\$ipe"
  fi
done

# export number of PE's and make jobs for mpsh:
# --------------------------------------------

export MPSH_NPES=$GMK_THREADS

ipe=1
while [ $ipe -le $MPSH_NPES ] ; do
  irank=$((ipe-1))
  if [ $irank -le 9 ] ; then
    MPSH_SECTION=000$irank
  elif [ $irank -le 99 ] ; then
    MPSH_SECTION=00$irank
  elif [ $irank -le 999 ] ; then
    MPSH_SECTION=0$irank
  elif [ $irank -le 9999 ] ; then
    MPSH_SECTION=$irank
  else
    echo Psystem : too much jobs.
    exit 1
  fi
# As peid does not exist on all machines:
  echo "export MPSH_PEID=$irank" >> mpsh.job.$MPSH_SECTION
  echo "export MPSH_SECTION=$MPSH_SECTION" >> mpsh.job.$MPSH_SECTION
  echo "export MPSH_INDEX=$ipe" >> mpsh.job.$MPSH_SECTION
  echo $(echo $MyCommand | sed "s/\$ipe/$ipe/g") >> mpsh.job.$MPSH_SECTION
  ipe=$((ipe+1))
done

# Invoke mpsh: 
# -----------

export MPSH_JOBS=$(perl -we 'print scalar grep /mpsh.job.\d+$/o, <mpsh.job.*>;')
$GMKROOT/mpsh/bin/mpsh 2>/dev/null
if [[ $? -ne 0 ]]; then
  echo error with mpsh
  exit 1
fi
exit 0
