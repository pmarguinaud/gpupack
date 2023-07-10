#!/bin/bash
########################################################################
#
#    Script updpack
#    --------------
#
#    Purpose : In the framework of a pack : to update pack content
#    -------   before compiling
#
#    Usage : updpack $1 $2 $3 $4
#    -----
#            $1 : (input) file containing the list of elements to update
#            $2 : (output) restricted list of element to compile
#            $3 : (output) restricted list of object file to get
#            $4 : (input) thread-private working directory
#
#    Environment variables :
#    ---------------------
#            ICS_ECHO : Verboose level (0 or 1 or 2)
#            MKMAIN   : directory of local source files
#            AWK      : awk program
#            GMKROOT  : gmkpack root directory
#            ALL_FILES_LIST : list of all files
#            ALL_DESCRIPTORS : descriptors for all modules in compilation list
#
########################################################################
#
export LC_ALL=C

WORKING_DIR=$4
mkdir -p $WORKING_DIR
cd $WORKING_DIR

\rm -f $2 $3

# Select files: this block is useful because ignored files could be dependencies.
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
egrep "(\.h$|\.inc$)" input_list.loc > headers_list
if [ -s headers_list ] ; then
# prepare list of intfb projects:
  touch $WORKING_DIR/vob_list
  for vob in $(eval echo $INTFB_ALL_LIST) ; do
    echo $vob >> $WORKING_DIR/vob_list
  done
# Remove out-of-date object file :
  cd $MKMAIN
  for file in $(cut -d "@" -f2 $WORKING_DIR/headers_list) ; do
    object=$(echo $file | sed -e "s/h$/ok/" -e "s/inc$/ok/")
#   Recursive destruction of dependencies for headers:
    if [ -f $object ] ; then
      find $(dirname $file) -name "$(basename $file)" -newer "$object" -exec \rm -f $object \; 2> /dev/null
      if [ ! -f $object ] ; then
#       Object was out-of-date, remove now its subsequent out-of-date dependencies :
#       Position of the file in the list:
#       Only things below should/could be deleted:
        radical=$(basename $object .ok)
#       The next sed contains a tabulation !! The trick is because cut/awk failed for too long lines
        for nextfile in $(grep "${radical}\.ok" $GMAKDIR/view | sed "s/[	]*=.*$//" | cut -d"'" -f2) ; do
          nextext=$(echo $nextfile | $AWK -F"." '{print $NF}')
          if [ "$nextext" = "h" ] || [ "$nextext" = "inc" ] ; then
            nextobj=$(dirname $nextfile)/$(basename $nextfile .${nextext}).ok
            if [ -f $nextobj ] ; then
              \rm -f $nextobj
              echo $nextobj removed by missing $object
            fi
          elif [ "$nextext" = "c" ] || [ "$nextext" = "cc" ] ; then
            nextobj=$(dirname $nextfile)/$(basename $nextfile .${nextext}).o
            if [ -f $nextobj ] ; then
              \rm -f $nextobj
              echo $nextobj removed by missing $object
            fi
          else
            N0=$(grep -nh "@${file}" $ALL_FILES_LIST | cut -d":" -f1)
            N1=$(grep -nh "@${nextfile}" $ALL_FILES_LIST | cut -d":" -f1)
            if [ $N1 -gt $N0 ] ; then
              nextobj=$(dirname $nextfile)/$(basename $nextfile .${nextext}).o
              if [ -f $nextobj ] ; then
                \rm -f $nextobj
                echo $nextobj removed by missing $object
              fi
            fi
          fi
        done
      fi
    fi
  done
  for file in $(cut -d "@" -f2 $WORKING_DIR/headers_list) ; do
    object=$(echo $file | sed -e "s/h$/ok/" -e "s/inc$/ok/")
#   "touch" modified headers :
    if [ -f $object ] ; then
      if [ $ICS_ECHO -gt 1 ] ; then
        echo Up to date : $file
      fi
    else
      touch $MKMAIN/$object
      vob=$(echo $file | cut -d"/" -f1)
      if [ "$vob" != ".intfb" ] ; then
        ii=$(echo $file | grep -c "\.intfb\.h$")
        if [ $ii -eq 0 ] ; then
          if [ ! -d .include/$vob/headers ] ; then
            mkdir -p .include/$vob/headers
          fi
          \ln -s -f ../../../$file .include/$vob/headers/$(basename $file)
        elif [ $(grep -c "${vob}" $WORKING_DIR/vob_list) -eq 0 ] ; then
          if [ ! -d .include/$vob/headers ] ; then
            mkdir -p .include/$vob/headers
          fi
          \ln -s -f ../../../$file .include/$vob/headers/$(basename $file)
        fi
        if [ $ICS_ECHO -gt 1 ] || [ $ii -eq 0 ] ; then
          echo "touched : $file"
        fi
      else
        if [ $ICS_ECHO -gt 1 ] ; then
          echo "touched : $file"
        fi
      fi
    fi
  done
  cd $WORKING_DIR
fi

# Select sql requests :
grep "\.sql$" input_list.loc > sql_list
if [ -s sql_list ] ; then
  declare -A sql_array
  cd $MKMAIN
  i=-1
  for element in $(cat $WORKING_DIR/sql_list) ; do
#   Object name : odb/ddl.${BASE}/request.sql => odb/ddl.${BASE}/${BASE}_request.o
    file=$(echo $element | cut -d"@" -f2)
    object=$(echo $file | sed -e "s/sql$/o/" -e "s/\/ddl\.\(.*\)\//\/ddl\.\1\/\1_/")
#   Remove out-of-date object file :
    if [ -f $object ] ; then
      find $(dirname $file) -name "$(basename $file)" -newer "$object" -exec \rm -f $object \; 2> /dev/null
    fi
    if [ -f $object ] ; then
      if [ $ICS_ECHO -gt 1 ] ; then
        echo Up to date : $file
      fi
    else
#      echo $element >> $WORKING_DIR/sql_outofdate
      i=$((i+1))
      sql_array[$i]=$element
    fi
  done
  cd $WORKING_DIR
  if [ $i -ge 0 ] ; then
#  if [ -s sql_outofdate ] ; then
    echo ${sql_array[*]} | tr " " "\n" > sql_outofdate
    cat sql_outofdate >> $2
    cut -d "@" -f2 sql_outofdate | sed -e "s/sql$/o/" -e "s/\/ddl\.\(.*\)\//\/ddl\.\1\/\1_/" >> $3
  fi
fi

# Select C code :
grep "\.c$" input_list.loc > c_list
if [ -s c_list ] ; then
  declare -A c_array
  cd $MKMAIN
  i=-1
  for element in $(cat $WORKING_DIR/c_list) ; do
    file=$(echo $element | cut -d"@" -f2)
    object=$(echo $file | sed -e "s/c$/o/")
#   Remove out-of-date object file :
    if [ -f $object ] ; then
      find $(dirname $file) -name "$(basename $file)" -newer "$object" -exec \rm -f $object \; 2> /dev/null
    fi
    if [ -f $object ] ; then
      if [ $ICS_ECHO -gt 1 ] ; then
        echo Up to date : $file
      fi
    else
#      echo $element >> $WORKING_DIR/c_outofdate
      i=$((i+1))
      c_array[$i]=$element
    fi
  done
  cd $WORKING_DIR
  if [ $i -ge 0 ] ; then
#  if [ -s c_outofdate ] ; then
    echo ${c_array[*]} | tr " " "\n" > c_outofdate
    cat c_outofdate >> $2
    cut -d "@" -f2 c_outofdate | sed -e "s/c$/o/" >> $3
  fi
fi

# Select CUDA code :
grep "\.cu$" input_list.loc > cu_list
if [ -s cu_list ] ; then
  declare -A cu_array
  cd $MKMAIN
  i=-1
  for element in $(cat $WORKING_DIR/cu_list) ; do
    file=$(echo $element | cut -d"@" -f2)
    object=$(echo $file | sed -e "s/cu$/o/")
#   Remove out-of-date object file :
    if [ -f $object ] ; then
      find $(dirname $file) -name "$(basename $file)" -newer "$object" -exec \rm -f $object \; 2> /dev/null
    fi
    if [ -f $object ] ; then
      if [ $ICS_ECHO -gt 1 ] ; then
        echo Up to date : $file
      fi
    else
#      echo $element >> $WORKING_DIR/cu_outofdate
      i=$((i+1))
      cu_array[$i]=$element
    fi
  done
  cd $WORKING_DIR
  if [ $i -ge 0 ] ; then
#  if [ -s cu_outofdate ] ; then
    echo ${cu_array[*]} | tr " " "\n" > cu_outofdate
    cat cu_outofdate >> $2
    cut -d "@" -f2 cu_outofdate | sed -e "s/cu$/o/" >> $3
  fi
fi

# Select C++ code :
for ext in cpp cc ; do
  grep "\.${ext}$" input_list.loc > c_list
  if [ -s c_list ] ; then
    declare -A cpp_array
    cd $MKMAIN
    i=-1
    for element in $(cat $WORKING_DIR/c_list) ; do
#   Define characteristics :
      file=$(echo $element | cut -d"@" -f2)
      object=$(echo $file | sed "s/${ext}$/o/")
#   Remove out-of-date object file :
      if [ -f $object ] ; then
        find $(dirname $file) -name "$(basename $file)" -newer "$object" -exec \rm -f $object \; 2> /dev/null
      fi
      if [ -f $object ] ; then
        if [ $ICS_ECHO -gt 1 ] ; then
          echo Up to date : $file
        fi
      else
        i=$((i+1))
        cpp_array[$i]=$element
      fi
    done
    cd $WORKING_DIR
    if [ $i -ge 0 ] ; then
      echo ${cpp_array[*]} | tr " " "\n" > cpp_outofdate
      cat cpp_outofdate >> $2
      cut -d "@" -f2 cpp_outofdate | sed -e "s/${ext}$/o/" >> $3
    fi
  fi
done

# Select Fortran code :
egrep "(\.f$|\.F$|\.f90$|\.F90$)" input_list.loc > o_list
if [ -s o_list ] ; then
  declare -A fortran_array
  cd $MKMAIN
  i=-1
  for element in $(cat $WORKING_DIR/o_list) ; do
#   Define characteristics :
    file=$(echo $element | cut -d"@" -f2)
    object=$(echo $file | sed -e "s/f$/o/" -e "s/F$/o/" -e "s/f90$/o/" -e "s/F90$/o/")
#   Remove out-of-date object file :
    if [ -f $object ] ; then
      dir=$(dirname $file)
      base=$(basename $file)
      unset NEWER
      NEWER=$(find $dir -name "$base" -newer "$object" 2> /dev/null)
      if [ "$NEWER" ] ; then
#       Object was out-of-date, identfy its subsequent out-of-date dependencies if the file is a module :
        ext=$(echo $base | $AWK -F"." '{print $NF}')
        radical=$(basename $base .${ext})
        modname=$(grep "${dir}/${radical}\.${ext}" $ALL_DESCRIPTORS | $AWK -F"'" '{print $4}')
        if [ "$modname" ] ; then
          export N0=$(grep -nh "@${dir}/${radical}\.${ext}" $ALL_FILES_LIST | cut -d":" -f1)
#         Only things below should/could be deleted:
#         The next sed contains a tabulation !! The trick is because cut/awk failed for too long lines
          grep "${modname}\.${MODEXT}" $GMAKDIR/view | sed "s/[	]*=.*$//" | cut -d"'" -f2 > $WORKING_DIR/thisdepslist
	  i=0
	  /bin/rm -f $WORKING_DIR/finaldepslist
	  while [ -s $WORKING_DIR/thisdepslist ] ; do
            i=$((i+1))
            if [ $ICS_ECHO -gt 1 ] ; then
# notice : 1 print per thread. Not very nice :-(
              echo "dependencies level $i"
            fi
	    if [ -s $WORKING_DIR/finaldepslist ] ; then
	      cat $WORKING_DIR/thisdepslist $WORKING_DIR/finaldepslist | sort -u > $WORKING_DIR/nextmodlist
	      comm -23 $WORKING_DIR/nextmodlist $WORKING_DIR/finaldepslist > $WORKING_DIR/thisdepslist
	      if [ $ICS_ECHO -gt 1 ] ; then
                echo Added :
	        cat $WORKING_DIR/thisdepslist
	      fi
              /bin/mv $WORKING_DIR/nextmodlist $WORKING_DIR/finaldepslist
            else
	      sort -u $WORKING_DIR/thisdepslist > $WORKING_DIR/finaldepslist
	      if [ $ICS_ECHO -gt 1 ] ; then
                echo Added :
	        cat $WORKING_DIR/finaldepslist
	      fi
	    fi
	    $GMKROOT/aux/nextupdpack.sh $WORKING_DIR/thisdepslist $WORKING_DIR/nextmodlist
            if [ -s $WORKING_DIR/nextmodlist ] ; then
              /bin/mv $WORKING_DIR/nextmodlist $WORKING_DIR/thisdepslist
            else
              /bin/rm $WORKING_DIR/thisdepslist
            fi
          done
          \rm -f $object
	  for nextfile in $(sort -u $WORKING_DIR/finaldepslist 2>/dev/null) ; do
            nextbase=$(basename $nextfile)
            nextdir=$(dirname $nextfile)
            nextext=$(echo $nextbase | $AWK -F"." '{print $NF}')
            nextobj=$nextdir/$(basename $nextbase .${nextext}).o
            if [ -f $nextobj ] ; then
              nextrad=$(basename $nextbase .${nextext})
              nextmod=$(grep "${nextdir}/${nextrad}\.${nextext}" $ALL_DESCRIPTORS | $AWK -F"'" '{print $4}')
              if [ "$nextmod" ] ; then
		if [ $ICS_ECHO -gt 1 ] ; then
                  echo misssing $object removes $nextobj and $nextdir/${nextmod}.${MODEXT}
	        fi
                \rm -f $nextobj $nextdir/${nextmod}.${MODEXT}
              else
		if [ $ICS_ECHO -gt 1 ] ; then
                  echo misssing $object removes $nextobj
	        fi
                \rm -f $nextobj
              fi
            fi
          done
        else
          \rm -f $object
        fi
      fi
    fi
    if [ -f $object ] ; then
      if [ $ICS_ECHO -gt 1 ] ; then
        echo Up to date : $file
      fi
    else
      i=$((i+1))
      fortran_array[$i]=$element
    fi
  done
  cd $WORKING_DIR
  if [ $i -ge 0 ] ; then
#  if [ -s fortran_outofdate ] ; then
    echo ${fortran_array[*]} | tr " " "\n" > fortran_outofdate
    cat fortran_outofdate >> $2
    cut -d "@" -f2 fortran_outofdate | sed -e "s/f$/o/" -e "s/F$/o/" -e "s/f90$/o/" -e "s/F90$/o/" >> $3
  fi
fi

cd $MKMAIN
\rm -rf $WORKING_DIR
