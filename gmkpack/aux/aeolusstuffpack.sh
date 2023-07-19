#!/bin/bash

# Written by Ryad El Khatib, 05-Jun-2008
# 
# One more time, a quick & dirty interface to compile aeolus.
# External compilation as been proven impossible since the interface to IFS,
# which contains YOMLUN_IFSAUX from the auxilary library and would contain 
# ODB modules later on, has no Makefile.

# Somehow, the gmkpack compilation system handles a database onto which the 
# compilation is performed.
# Therefore in such an environment there could not be links to 'new' source files 
# because : 
# - modules would be seen as duplicated while they should be kept unique. If they were
# multiple, one should be awfully careful with the locality of them with respect
# to the subroutine to compile, and with the -I argument.
# - it would look like the database is changed be the compîlation, not the developer.

# To survive to the duplicated modules of Aeolus as far as portability is
# concerned, a supplementary information should be supplied.
# In most of the other source code that I know, this is achieve by a unique code
# using cpp macros. In Aeolus they use scripts, using % uname or considering the
# compiler used (defined in an aeolus environment variable).
# But using the compiler name is clumsy because sometimes you want to use a 
# wrapper of it ! And again, because ARCH may be let undefined on some platforms
# and since a platform can have many compilers, including cross-compilers, the 
# relationship between the "compiler features extension" (recalling the compiler) 
# and the actual label used (recalling either the compiler or the operating system)
# is not straightforward.
# Therefore we use here a label defined at the time of the setup of the configuration
# file of gmkpack to identify the proper "compiler_features" file to use.
# In other words, we are using here a pseudo cpp macro.
# Allowing actual cpp macros in Aeolus would have been much more confortable ...

# More problems :
# There are subroutines which are not ready : I mean the source code is there, but
# the compilation grammar is wrong. So they should be excluded, but where is the list
# of them ? 

# Finally ECMWF has got a hard-coded list of what should be ignored, as we do here ... 
# It causes maintenance problems, unless we can agree to have this list maintained inside
# Aeolus.

export LC_ALL=C

packlist=$1

if [ $(grep ^aeo\/ $packlist | wc -l) -ne 0 ] ; then
# Meteo-France naming convention
  VOB=aeo
elif [ $(grep ^aeolus\/ $packlist | wc -l) -ne 0 ] ; then
# ECMWF naming convention
  VOB=aeolus
else
# No aeolus stuff
  exit 0
fi

MyTmp=$GMKWRKDIR/aeostuffpack
mkdir -p $MyTmp
cd $MyTmp

echo Check aeolus content ...

grep "^${VOB}\/" $packlist | sort -u > packlist.aeo
grep -v "^${VOB}\/" $packlist > packlist.others

ierr=0
if [ -s packlist.aeo ] ; then
  if [ ! "$GMK_AEOLUS_F90" ] && [ ! "$GMK_AEOLUS_LATLON_HANDLING" ] ; then
    echo
    echo "ERROR ! Your configuration file is missing the variables"
    echo "GMK_AEOLUS_F90 and GMK_AEOLUS_LATLON_HANDLING"
    echo "Refer to the configuration files templates (\$GMKROOT/arch)"
    echo "to find the proper value for these variables"
    ierr=1
  elif [ ! "$GMK_AEOLUS_F90" ] ; then
    echo "ERROR ! Your configuration file is missing the variable GMK_AEOLUS_F90"
    echo "Refer to the configuration files templates (\$GMKROOT/arch)"
    echo "to find the proper value for this variable"
    ierr=1
  elif [ ! "$GMK_AEOLUS_LATLON_HANDLING" ] ; then
    echo "ERROR ! Your configuration file is missing the variable"
    echo "GMK_AEOLUS_LATLON_HANDLING "
    echo "Refer to the configuration files templates (\$GMKROOT/arch)"
    echo "to find the proper value for this variable"
    ierr=1
  fi
  if [ $ierr -eq 0 ] ; then
    export GMK_TMPDIR=$MyTmp
    INPUT_LIST=$(\ls -1t $MKTOP/*/${VOB}/Scripts/arpifs_excluded_files 2>/dev/null | head -1)
    SETUP_SCRIPT=$(\ls -1t $MKTOP/*/${VOB}/Scripts/do_aeolus_setup_for_gmkpack 2>/dev/null | head -1)
#    unset INPUT_LIST SETUP_SCRIPT
#    for branch in $(cat 
#    while [ ! "$INPUT_LIST" ] ; do
#    done
    \cp $SETUP_SCRIPT /tmp/setup_aeolus
    chmod 755 /tmp/setup_aeolus
    /tmp/setup_aeolus $INPUT_LIST >  outputlist
#   can't source file and use /dev/shm because of the silly "exit 0" I put in the script !!! REK
    ierr=$?
    if [ $ierr -ne 0 ] ; then
      cat outputlist
    else
      sed "s/^/${VOB}\//" outputlist > outputlist.new
      comm -12 packlist.aeo outputlist.new > ignored
      if [ -s ignored ] ; then
        echo WARNING : following files are now ignored :
        cat ignored
        comm -23 packlist.aeo outputlist.new > packlist.aeo.new
        cat packlist.others packlist.aeo.new > $packlist
      fi
    fi
    /bin/rm /tmp/setup_aeolus
  fi
fi
# Finish
# ------
cd $GMKWRKDIR
\rm -rf aeostuffpack
if [ $ierr -eq 0 ] ; then
  exit 0
else
  exit 1
fi
