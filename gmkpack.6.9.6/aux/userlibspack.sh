#!/bin/bash
########################################################################
#
#    Script userlibspack
#    -------------------
#
#    Purpose : In the framework of a pack : to make archive libraries
#    -------
#
#    Usage : userlibspack
#    -----
#
#    Environment variables :
#    ---------------------
#            MKLIB     : directory of libraries
#            MKLINK    : directory of binaries
#            MKTOP     : directory of all source files
#            GMKWRKDIR    : main working directory
#            AWK       : awk program
#            AR        : ar command
#            GMKROOT   : gmkpack root directory
#            ICS_PROJLIBS  : list of projects
#            ICS_UPDLIBS : libraries update mode
#
##########################################################################

export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

echo
echo ------ Make/Update user libraries -----------------------------------
echo
#
MyTmp=$GMKWRKDIR/userlibspack
mkdir -p $MyTmp
find $MyTmp -name "*" -type f | xargs /bin/rm -f 

target=$(uname -s | tr '[A-Z]' '[a-z]')

if [ "$GMK_IGNORE_MULTINAME" ] ; then
  MESSAGE="WARNING"
else
  MESSAGE="FATAL ERROR"
fi

# Directory where to store F90 files generated from .fypp files
if [ ! "$GMKFYPPF90" ] ; then
  export GMKFYPPF90=.fypp
fi

cd $MyTmp
for project in $(echo $ICS_PROJLIBS) ; do
  find $MKTOP/$GMKLOCAL/$project -type d | sed "s:^$MKTOP/$GMKLOCAL/$project::" | grep "^/" | sed "s:^/::" > all_dirs
  sort -u all_dirs > all_dirs.su 2>/dev/null
  \mv all_dirs.su all_dirs
  cat $GMKROOT/libs/$project/* 2>/dev/null | sort -u > sub_dirs
# Scan sections and complement :
  for section in . $(\ls -1 $GMKROOT/libs/$project 2> /dev/null) ; do
    if [ "$section" = "." ] ; then
      section=""
      dirlist="$(echo $(comm -23 all_dirs sub_dirs))"
    else
      dirlist="$(echo $(cat $GMKROOT/libs/$project/$section))"
    fi
    loclib=lib${section}${project}.${GMKLOCAL}.a
    abslib=${MKLIB}/$loclib
    \rm -f *.o
#   Start with those files which are not below a directory (unfair behavior !)
    if [ "$section" = "" ] ; then
      for object in $(\ls -1 $MKTOP/$GMKLOCAL/$project $MKTOP/$GMKLOCAL/$GMKFYPPF90/$project 2>/dev/null | grep "\.o$") ; do
        if [ -f $(basename $object) ] ; then
          cmp -s $object $(basename $object)
          if [ $? -ne 0 ] ; then
            echo
            echo " *** ambiguous file $(basename $object) for archive $loclib ***"
            echo
            echo "Remove library $loclib ..."
            \rm -f $abslib
            echo "Remove binaries ..."
            for file in $MKLINK/* ; do
              if [ ! -L $file ] ; then
                \rm -f $file
              fi
            done
            echo "Abort job."
            cd $GMKWRKDIR
            \rm -rf userlibspack
            exit 1
          else
            echo " *** ignoring identical object file $(basename $object) for archive $loclib ***"
          fi
        else
          \cp -p $object .
        fi
      done
    fi
#   Normal ones :
    for dir in $(eval echo $dirlist) ; do
      if [ -d $MKTOP/$GMKLOCAL/$project/$dir ] ; then 
#       Because dir might not exist if source dir had not been fully filled
        for tree in $MKTOP/$GMKLOCAL/$project/$dir $MKTOP/$GMKLOCAL/$GMKFYPPF90/$project/$dir ; do
          for object in $(\ls -1 $tree 2>/dev/null | grep "\.o$") ; do
            if [ -f $object ] ; then
#             An object of the same name already exists : check if it is a duplicate or not
              cmp -s $tree/$object $object
              if [ $? -ne 0 ] ; then
                echo 
                echo " *** ambiguous file $object for archive $loclib ***"
                echo 
                echo "Remove library $loclib ..."
                \rm -f $abslib
                echo "Remove binaries ..."
                for file in $MKLINK/* ; do
                  if [ ! -L $file ] ; then
                    \rm -f $file
                  fi
                done
                echo "Abort job."
                cd $GMKWRKDIR
                \rm -rf userlibspack
                exit 1
              else
                echo " *** ignoring identical object file $(basename $object) for archive $loclib ***"
              fi
            else
              \cp -p $tree/$object .
            fi
          done
        done
      fi
    done
    if [ $(find . -name "*.o" -print | wc -l) -gt 0 ] ; then
      unset Out_of_date 
      if [ -f $abslib ] ; then
#       Control whether the lib is up to date or not (by checking date then content) :
        \rm -f list.new
        find . -name "*.o" -newer $abslib -print > list.new
        if [ -s list.new ] ; then
          Out_of_date=date
        fi
        if [ ! "$Out_of_date" ] ; then
#         Select only *.o in archive (systems like OS X add a header to tell
#         whether the archive is sorted or not)
          $AR -t $abslib | grep "\.o$" | sort > lib.list
          find . -name "*.o" -print | sort > loc.list
          cmp -s lib.list loc.list
          if [ $? -eq 0 ] ; then
            Out_of_date="content"
          fi
        fi
      else
        Out_of_date="missing"
      fi
      if [ "$Out_of_date" ] ; then
        \rm -f $abslib
        if [ -f loc.list ] ; then
          if [ "$target" = "darwin" ] ; then
            cat loc.list | xargs $AR -qvS $abslib
            ranlib -a -no_warning_for_no_symbols $abslib 2>/dev/null
          else
            cat loc.list | xargs $AR -qv $abslib
          fi
        else
          if [ "$target" = "darwin" ] ; then
            find . -name "*.o" -print | xargs $AR -qvS $abslib
            ranlib -a -no_warning_for_no_symbols $abslib 2>/dev/null
          else
            find . -name "*.o" -print | xargs $AR -qv $abslib
          fi
        fi
#       Control the unicity of symbols in the text section of the library 
#       except for fortran main entries:
#       NB : 2>/dev/null to filter messages fromOS X.
#       Could become useless when ranlib is replaced by libtool?
        $NMOPTS -pg $abslib 2>/dev/null | grep " T " | $AWK '{print $NF}' | grep -vi main | sort > textsymbols.list
        sort -u textsymbols.list > textsymbols_unique.list
        NSYMBOLS=$(cat textsymbols.list 2>/dev/null | wc -l)
        NSYMBOLS_UNIQUE=$(cat textsymbols_unique.list 2>/dev/null | wc -l)
#       see the dirty fix for macos :
	if [ $NSYMBOLS -ne $NSYMBOLS_UNIQUE ] && [ "$project" != "oops_src" ] && [ "$target" != "darwin" ] ; then
          ALL_COUNT=0
          for symbol in $(comm -23 textsymbols.list textsymbols_unique.list | sort -u) ; do
            NCOUNT=0
            for obj in $($AR -t $abslib) ; do
#             (__.SYMDEF appears with Mac OS X only)
              if [ "$obj" != "__.SYMDEF" ] ; then
                if [ $($NMOPTS -p $obj 2>/dev/null | egrep "( T | t )" | grep -ci main) -eq 0 ] ; then
                  if [ $($NMOPTS -p $obj 2>/dev/null | grep " T " | grep -c "$symbol") -ne 0 ] ; then
                    NCOUNT=$((NCOUNT+1))
                    if [ $NCOUNT -eq 1 ] ; then
                      echo "$MESSAGE in library $loclib : detection of a duplicated symbols named $symbol in the following objects:"
                    fi
                    echo "  $obj"
                  fi
                fi
              fi
            done
            ALL_COUNT=$((ALL_COUNT+NCOUNT))
          done
          if [ ! "$GMK_IGNORE_MULTINAME" ] && [ $ALL_COUNT -ne 0 ] ; then
            echo
            echo "Abort job."
	    \rm $abslib
            cd $GMKWRKDIR
            \rm -rf userlibspack
            exit 1
          fi
        fi
      else
        echo "library $loclib is up to date"
      fi
      \rm -f lib.list loc.list
    elif [ -f $abslib ] ; then
#     This case is important !!
      echo "Remove out-of-object library $loclib ..."
      \rm -f $abslib
    fi
  done
done
#
cd $GMKWRKDIR
\rm -rf userlibspack
