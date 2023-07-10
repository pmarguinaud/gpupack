#!/bin/bash
########################################################################
#
#    Script loadpack
#    --------------
#
#    Purpose : In the framework of a pack : to make links edition
#    -------   
#
#    Usage : loadpack
#    -----
#            $1 : leading object files (entry point, etc)
#            $2 : file containing the ordered list of libraries to load
#            $3 : binary name
#            $4 : file containing the ordered list of system libraries to load
#            $5 : file containing the loader name and loading options
#            $6 : "ODBGLUE" if needed
#
#    Environment variables :
#    ---------------------
#            GMKWRKDIR : main working directory
#            ICS_ERROR : error file
#            MKTOP     : directory of all source files
#            GMKVIEW   : list of branches, from bottom to top
#            AWK       : awk program
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

MyTmp=$GMKWRKDIR/loadpack
mkdir -p $MyTmp
find $MyTmp -name "*" -type f | xargs /bin/rm -f
cd $MyTmp

export GMK_BINARY_NAME=$3

MAX_CYCLE=2
MAX_CYCLE=1
target=$(uname -s | tr '[A-Z]' '[a-z]')
if [ ! "$LNK_STARTG" ] && [ ! "$LNK_ENDG" ] ; then
  EXPLICIT_CYCLING=1
else
  EXPLICIT_CYCLING=0
fi

if [ "$ICS_MAP" = "yes" ] ; then
  MY_MAP="$LNK_MAP"
else
  unset MY_MAP
fi

jj=0
if [ -s $2 ] ; then
  echo "Top libraries actually used :"
  ii=0
  for ulib in $(cat $2 2>/dev/null) ; do
    ii=$((ii+1))
    link=$(\ls -l $ulib | $AWK '{print $NF}')
    if [ ! -f $link ] ; then
#     we search (nicely) a relative link
      baselib=$(basename $ulib)
      dirlib=$(dirname $ulib)
      mydir=$pwd
      cd $dirlib
      link=$dirlib/$(\ls -l $baselib | $AWK '{print $NF}')
      cd $mydir
    fi
    if [ -f $link ] ; then
      if [ $ii -le 9 ] ; then
        echo "lib[0$ii].a=\"$link\""
      else
        echo "lib[$ii].a=\"$link\""
      fi
     \ln -sf $link lib[${ii}].a
    else
      echo "$link still missing !!"
    fi
  done
  jj=$ii
#
  if [ $EXPLICIT_CYCLING -eq 1 ] ; then
    echo
    if [ $jj -le $MAX_CYCLE ] ; then
      echo "Explicit cycling research of libraries ..."
      LIBMIX=0
    else
      mkdir mixdir
      NKEPTLIBS=$((jj-MAX_CYCLE))
      MAX_SIZE=$(\ls -l $(\ls -l lib*.a | $AWK '{print $NF}') | sort -k5,6 -nbr | $AWK '{print $5}' | head -$MAX_CYCLE | tail -1)
      echo "Explicit cycling research of libraries, with a mix of those smaller than $((MAX_SIZE/1048576)) Mbytes ..."
      LIBMIX=1
    fi
  fi
#
fi
#
echo
echo "Search entry point ..."
ii=0
touch entry_list

for file in $(echo $1) ; do
  for branch in $(echo $GMKVIEW) ; do
    found_file=$(eval echo $MKTOP/$branch/$file)
    if [ -f $found_file ] ; then
      \cp $found_file .
    fi
  done
  if [ -s $(basename $found_file) ] && [ $(grep -c $(basename $found_file .o) entry_list) -eq 0 ] ; then
#   This entry_list file enables not to count a given object file (basename) more than once
    echo $(basename $found_file .o) >> entry_list
    ii=$(($ii+1))
    entry_array[$ii]=./$(basename $found_file)
  elif [ -f $(basename $found_file) ] ; then
#   GCO gmak can work so :-(
    echo "Warning: empty file $found_file"
  else
    echo "Warning: no file $file"
  fi
done

if [ $ii -eq 0 ] ; then
  echo "Can t find any entry object file $1 !!"
  touch $ICS_ERROR
  find $MyTmp -name "*" -type f | xargs /bin/rm -f
  cd $MyTmp
  exit
fi

# Add odbglue if needed : the test below is quite critical
# to find if the current release is older thant CY32
# alas, world is not perfect if [ ! -f $MKTOP/$GMKMAIN/odb/lib/Codb_set_entrypoint.o ] ; then
if [ "$6" = "ODBGLUE" ] ; then
if [ ! -f $MKTOP/*/odb/lib/PREODB_static_init.c ] ; then
  unset list_of_labels
  cat $2 | $AWK -F "/" '{print $NF}' | grep "^lib" | grep "\-odb\." | grep "\.a$" | cut -c4- | cut -d "-" -f1 | sort -u > .found_stamps
  if [ -s .found_stamps ] ; then
    \rm -f .possible_bases
    for stamp in $(cat .found_stamps 2>/dev/null) ; do
      cat $GMKROOT/libs/odb/${stamp}- >> .possible_bases
    done
    for label in $(echo $(\ls -1 $MKTOP/*/odb/ | grep "^ddl\." | cut -d "." -f2- | sort -u)) ; do
      if [ $(grep -c $label .possible_bases) -ne 0 ] ; then
#       Main packs : search in $GMKUNSX :
        if [ -f $MKTOP/$GMKUNSX/$GMKUNSX_VERBOOSE/${label}_Sstatic.c ] ; then
          list_of_labels="$list_of_labels $label"
        elif [ -d $MKTOP/$GMKMAIN ] ; then
#         User packs : search in ~/$GMKMAIN/$GMKUNSX :
          MAINGMKUNSX=$(\ls -l $MKTOP/$GMKMAIN | $AWK '{print $NF}')/../$GMKUNSX
          if [ -f $MAINGMKUNSX/$GMKUNSX_VERBOOSE/${label}_Sstatic.c ] ; then
            list_of_labels="$list_of_labels $label"
          fi
        fi
      fi
    done
  fi
  \rm -f .possible_bases .found_stamps
  if [ "$list_of_labels" ] ; then
    ii=$(($ii+1))
    entry_array[$ii]=./_odb_glue.o
    echo glue bases $list_of_labels
    export ODB_CC="$VCCNAME"
    $GMKROOT/aux/create_odbglue.sh $list_of_labels
  fi
fi
fi
#
if [ $ii -ne 0 ] ; then
  $AR -qvs ./lib[0].a ${entry_array[*]}
  \rm -f ${entry_array[*]}
fi

echo
ii=0
\rm -f .list_of_biglibs .list_of_otherlibs
# Remove an object when already in a previous library
echo "scan for multiple defined symbols:"
\rm -f table.current
touch table.current
while [ $ii -le $jj ] ; do
  echo "scanning lib[${ii}].a ..."
# The next large conditional block now currently desabled
  if [ "$GMK_ENABLE_OBJ_RENAME" = "YES" ] ; then
    if [ "$target" = "darwin" ] ; then
#     The grep below is for OS X ;-)
      $AR t lib[${ii}].a | grep "\.o$" | sort > table.next
    else
      $AR t lib[${ii}].a | sort > table.next
    fi
    comm -12 table.current table.next > table.comm
    if [ -s table.comm ] ; then
      for object in $(cat table.comm) ; do
        $AR x lib[${ii}].a $object
#       rename objects if only 1 symbol inside with a different name (how nice !)
#       (but how dangerous, too, and fragile :
#       No renaming if $symbol = _$object (case g95/gfortran).
#       and MAIN is a problem, too.
#       Better not do that. If such a message appears
#       that an object file has been moved, then there is a real potential problem
#       in the code.
#       later all this filtering of multiplied defined objects should be replaced
#       by a true filtering of multiplied defined symbols ... as far as possible.
        if [ $($NMOPTS -p $object | grep " T " | grep -c "_$") -eq 1 ] ; then
          symbol=$($NMOPTS -p $object | grep " T " | grep "_$" | $AWK '{print $NF}' | sed "s/_$//" | sed "s/^\.//")
          if [ "${symbol}.o" != "$object" ] && [ "$symbol" != "MAIN" ] && [ "$symbol" != "_MAIN" ] && [ "${symbol}.o" != "_${object}" ] ; then
            echo mv $object ${symbol}.o
            \mv $object ${symbol}.o
            if [ -L lib[${ii}].a ] ; then
              echo Copy and prune library of :
              \cp lib[${ii}].a .lib[${ii}].a
              \rm lib[${ii}].a
              \mv .lib[${ii}].a lib[${ii}].a
            fi
            $AR d lib[${ii}].a $object
            $AR q lib[${ii}].a ${symbol}.o
          fi
#       C-style
#       No, finally don't do that because it causes HUGE problems because of ODB *_static_init voids
#       elif [ $($NMOPTS -p $object | grep -c " T ") -eq 1 ] ; then
#         symbol=$($NMOPTS -p $object | grep " T " | $AWK '{print $NF}' | sed "s/^\.//")
#         if [ "${symbol}.o" != "$object" ] && [ "$symbol" != "MAIN" ] ; then
#           echo mv $object ${symbol}.o
#           \mv $object ${symbol}.o
            if [ -L lib[${ii}].a ] ; then
              echo Copy and prune library of :
              \cp lib[${ii}].a .lib[${ii}].a
              \rm lib[${ii}].a
              \mv .lib[${ii}].a lib[${ii}].a
            fi
#           $AR d lib[${ii}].a $object
#           $AR q lib[${ii}].a ${symbol}.o
#         fi
        fi
        \rm -f $object
      done 
    fi
  fi
# Remove re-defined object on any bottom library
  if [ "$target" = "darwin" ] ; then
#   The grep below is for OS X ;-)
    $AR t lib[${ii}].a | grep "\.o$" | sort > table.next
  else
    $AR t lib[${ii}].a | sort > table.next
  fi
  comm -12 table.current table.next > table.comm
  if [ -s table.comm ] ; then
    if [ -L lib[${ii}].a ] ; then
      echo Copy and prune library of :
      \cp lib[${ii}].a .lib[${ii}].a
      \rm lib[${ii}].a
      \mv .lib[${ii}].a lib[${ii}].a
    fi
    if [ "$target" = "darwin" ] ; then
      $AR dvS lib[${ii}].a $(cat table.comm)
      if [ $EXPLICIT_CYCLING -eq 0 ] || [ $LIBMIX -eq 0 ] ; then
        ranlib -no_warning_for_no_symbols lib[${ii}].a
        if [ $? -ne 0 ] ; then
          echo Problem while running ranlib
          exit 1
        fi
#     else, we postpone the sorting, on the mixed and pruned libraries for darwin:
      fi
    else
      $AR dvs lib[${ii}].a $(cat table.comm)
    fi
  fi    
  cat table.current table.next | sort -u > table.new
  \mv table.new table.current
  if [ $ii -eq 0 ] ; then
    $AR x ./lib[0].a
    if [ -s $2 ] ; then
      listoflibs="$(echo $(\ls ${entry_array[*]}) -L.)"
    else
      listoflibs="$(echo $(\ls ${entry_array[*]}))"
    fi
  else
    N_next=$(cat table.next | wc -l)
    N_comm=$(cat table.comm | wc -l)
    N_final=$((N_next-N_comm))
    if [ $N_final -ne 0 ] ; then
      if [ $EXPLICIT_CYCLING -eq 0 ] ; then
        listoflibs="$listoflibs -l[${ii}]"
      elif [ $LIBMIX -eq 0 ] ; then
#       Pure explicit cycling research if there are only a few libraries:
        echo $ii >> .list_of_biglibs
      else
#       Keep the libraries bigger than about 50 Mo and mix the other ones
        LIBSIZE=$(\ls -l $(\ls -l lib[${ii}].a | $AWK '{print $NF}') | $AWK '{print $5}')
        if  [ $LIBSIZE -ge $MAX_SIZE ] ; then
          echo Keep lib[${ii}].a
          echo $ii >> .list_of_biglibs
        else
          echo Extract members of lib[${ii}].a ...
          cd mixdir
          $AR x ../lib[${ii}].a
          cd ../ 
          echo lib[${ii}].a >> .list_of_otherlibs
        fi
      fi
    else
      echo "Ignore empty lib[${ii}].a => remove it"
      \rm lib[${ii}].a
    fi
  fi
  ii=$(($ii+1))
done

if [ $EXPLICIT_CYCLING -eq 1 ] ; then
  echo
# Execute the postponed ranlib:
  if [ "$target" = "darwin" ] && [ $LIBMIX -eq 1 ] && [ -s .list_of_biglibs ] ; then
#   sort the kept libraries if they have been pruned :
    for ikept in $(cat .list_of_biglibs) ; do
      if [ ! -L lib[${ikept}].a ] ; then
        echo ranlib lib[${ikept}].a ...
        ranlib -no_warning_for_no_symbols lib[${ikept}].a
        if [ $? -ne 0 ] ; then
          echo Problem while running ranlib
          exit 1
        fi
      fi 
    done
  fi
# Make the mix library:
  if [ -s .list_of_otherlibs ] ; then
    echo Mix libraries $(echo $(cat .list_of_otherlibs)) ...
    cd mixdir
    if [ "$target" = "darwin" ]  ; then
      find . -name "*.o" | xargs $AR qS ../lib[X].a
      if [ $? -ne 0 ] ; then
        echo Problem while running $AR
        exit 1
      fi
      echo Make table-of-content of mixed libraries ...
      ranlib -no_warning_for_no_symbols ../lib[X].a 2>/dev/null
      if [ $? -ne 0 ] ; then
        echo Problem while running ranlib
        exit 1
      fi
    else
      $AR qs ../lib[X].a *.o 2>/dev/null
    fi
    cd ../
    echo X >> .list_of_biglibs
  fi
# Build the command line:
  sed -e "s/^/-l[/" -e "s/$/]/" .list_of_biglibs > .syntax_of_libs
  \rm -f .cycle_of_libs
  while [ $(cat .syntax_of_libs | wc -l) -ne 0 ] ; do
    cat .syntax_of_libs >> .cycle_of_libs
    sed "$ d" .syntax_of_libs > .syntax_of_libs_head
    \mv .syntax_of_libs_head .syntax_of_libs
  done
  listoflibs="$listoflibs $(echo $(cat .cycle_of_libs))"
  \rm -rf mixdir
fi

# if compiled with DR_HOOK_ALL, then bring in the special libraries
#
if [ "x$GMK_DR_HOOK_ALL" != "x" ] ; then
  listofdrhooklibs=$($GMKROOT/aux/drhook_all.pl --ldflags $GMK_DR_HOOK_ALL_FLAGS)
  listoflibs="$listoflibs $listofdrhooklibs"
fi

MYLOAD="$(echo $(cat $5)) $MY_MAP $LNK_STARTG $(echo $listoflibs) $LNK_ENDG $(echo $(cat $4))"
echo
echo $MYLOAD
#
\rm -f $3
touch now
sleep 1
eval $(echo $MYLOAD) 2> .stderr 1> .stdout
ERR_LOAD=$?

if [ ! -s a.out ] ; then
  cat .stderr .stdout 2>/dev/null
  touch $ICS_ERROR
elif [ $ERR_LOAD -ne 0 ] ; then
  \rm a.out
  cat .stderr .stdout 2>/dev/null
  echo "Error status $ERR_LOAD has been returned by $(basename $(echo $MYLOAD | cut -d' ' -f1))"
  touch $ICS_ERROR
elif  [ $ICS_ECHO -ge 2 ] || [ "$MY_MAP" ] ; then
  cat .stdout 2>/dev/null
fi
if [ "$MY_MAP" ] ; then
  find * -name "*" \( ! -type d \) -newer $MyTmp/now -print | grep -v "a\.out" | xargs cat 2>/dev/null
fi
#
echo
if [ -s a.out ] ; then
  set -x
  \mv a.out $3
  set +x
  \ls -l $3
  cd $GMKWRKDIR
  \rm -rf loadpack
else
  cd $GMKWRKDIR
  \rm -rf loadpack
  exit 1
fi
