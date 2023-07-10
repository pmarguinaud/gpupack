#!/bin/bash
########################################################################
#
#    Script odbstuffpack
#    --------------
#
#    Purpose : In the framework of a pack : to compile .ddl files and
#    -------   update the static stubb files
#
#    Usage : odbstuffpack $1
#    -----
#               $1 : pack content to update (in/out)
#
#    Environment variables :
#    ---------------------
#            MKTOP      : directory of all source files
#            GMKWRKDIR     : main working directory
#            GMKROOT    : gmkpack root directory
#            MKMAIN
#            ODB98NAME
#            MODINC
#            AWK
#            CPP
#            MACROS_CC
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

packlist=$1
MyTmp=$GMKWRKDIR/odbstuffpack
mkdir -p $MyTmp
cd $MyTmp
#
export ODB_SETUP_SHELL=$SHELL

project=odb

# "Shrink" packlist by removing what is not-used
# ----------------------------------------------
#
echo Check odb content ...

if [ $(cat $packlist | grep -c "^odb\/bufr2odb\/b2o\/") -ne 0 ] ; then
# There is a directory b2o, sign of cycle 49 or later : filter out bufr2odb directory
  BUFR2ODB=bufr2odb
fi

\cp $packlist packlist.bak
for dir in \
  extras \
  preodb \
  bufrbase \
  postodb \
  ddl.POSTODB \
  ddl.PREODB \
  prescreen \
  ddl.PRESCREEN \
  y2k.obsolete \
  examples \
  ddl \
  build \
  build_mf \
  compiler \
  scripts \
  doc \
  man \
  perl \
  bintmp \
  flags \
  odbsql \
  odbdummy \
  $BUFR2ODB \
  ; do
  if [ $(grep ^odb\/${dir}\/ $packlist | wc -l) -ne 0 ] ; then
    echo WARNING : Content of directory odb/$dir is now ignored :
    grep ^odb\/${dir}\/ $packlist
    grep -v ^odb\/${dir}\/ $packlist > mylist
    \mv mylist $packlist
  fi
done

# Now remove Netcdf dummies:
\cp $packlist packlist.bak
grep -v "^odb\/lib\/Dummies_netcdf.c$"  packlist.bak > $packlist

#
# Check that .ddl files match the presence of .sql files
# ------------------------------------------------------
#
for dir in $(\ls $MKMAIN/odb 2>/dev/null) ; do
  if [ -d $MKMAIN/odb/$dir ] ; then
    if [ $(grep -c "^odb\/${dir}\/.*\.sql$" $packlist) -ne 0 ] ; then
      if [ $(\ls -1 $MKTOP/*/odb/${dir}/*.ddl | wc -l) -eq 0 ] ; then
        echo WARNING : odb/$dir contains .sql files but no .ddl files ! Ignored files :
        grep "^odb\/${dir}\/.*\.sql$" $packlist
        grep -v "^odb\/${dir}\/.*\.sql$" $packlist > mylist
        \mv mylist $packlist
      fi
    fi
  fi
done
#
# Extract NMXUPD from cma.h if ODB_NMXUPD is not manually set and not already known
# ---------------------------------------------------------------------------------
NVIEW=$(echo $GMKVIEW | tr " " "\n" | wc -l)
if [ $NVIEW -gt 1 ] ; then
# user packs use the value of the source pack (even if old script with manual access) :
  if [ -s $MKTOP/.odb_nmxupd ] ; then
    export ODB_NMXUPD=$(echo $(cat $MKTOP/.odb_nmxupd))
  elif [ -s $SOURCE_PACK/$GMKSRC/.odb_nmxupd ] ; then
    export ODB_NMXUPD=$(echo $(cat $SOURCE_PACK/$GMKSRC/.odb_nmxupd))
    echo "$ODB_NMXUPD" > $MKTOP/.odb_nmxupd
  else
#   Old main pack : this is embarrassing because it is difficult to find out which value was used.
#   Then, then value must be set manually
    if [ "$ODB_NMXUPD" ] ; then
#     we assume the value is correct :
      echo "$ODB_NMXUPD" > $MKTOP/.odb_nmxupd
    else
      echo "odb_nmxupd must be set in the script !"
      cd $GMKWRKDIR
      \rm -rf odbstuffpack
      exit 1
    fi
  fi  
elif [ ! "$ODB_NMXUPD" ] ; then
# Not manually set, then find it :
# Search the compilation flags in the general ddl directory,
# only for main pack : we don't want to mix the number of updates from one branch to the other !
  CMA_H=$(\ls -1t $MKTOP/*/odb/ddl/cma.h 2>/dev/null | tail -1)
  if [ "$CMA_H" ] ; then
    if [ -s $CMA_H ] ; then
#     The file cma.h exists, use preprocessor on cma.h to get the actual value of NMXUPD
#     in case is is defined by a cpp macro
      $VCCNAME -E -P -x c $GMK_CFLAGS_ODB $CMA_H > cma
#     Find if the setup of the number of updates is unique
      ODB_NMXUPD=$(cat cma | egrep 'SET[\t ]*\$NMXUPD[\t ]*=' | sed 's/[$=;]/ /g' | awk '{print $3}' | wc -l)
      if [ $ODB_NMXUPD -eq 1 ] ; then
#       the number of updates can be safely extracted, get it :
        export ODB_NMXUPD=$(cat cma | egrep 'SET[\t ]*\$NMXUPD[\t ]*=' | sed 's/[$=;]/ /g' | awk '{print $3}')
      elif [ ! -s cma ] ; then
#       Give it another chance : the "preprocessor" used here is a compiler, and it can even be a wrapper of a compiler
#       which would not consider a header to be compiled/preprocessed. Therefore we should use a symbolic link to cheat it :
        \ln -s $CMA_H cma.c
        $VCCNAME -E -P -x c -c $GMK_CFLAGS_ODB cma.c > cma 2>/dev/null
        /bin/rm cma.c
#       Find if the setup of the number of updates is unique
        ODB_NMXUPD=$(cat cma | egrep 'SET[\t ]*\$NMXUPD[\t ]*=' | sed 's/[$=;]/ /g' | awk '{print $3}' | wc -l)
        if [ $ODB_NMXUPD -eq 1 ] ; then
#         the number of updates can be safely extracted, get it :
          export ODB_NMXUPD=$(cat cma | egrep 'SET[\t ]*\$NMXUPD[\t ]*=' | sed 's/[$=;]/ /g' | awk '{print $3}')
        fi
      fi
      /bin/rm cma
    fi
  fi
# Save the value, it will be used for user packs :
  echo "$ODB_NMXUPD" > $MKTOP/.odb_nmxupd
fi

# Remove .sql files of updates higher than the maximum supported
# --------------------------------------------------------------
if [ "$ODB_NMXUPD" ] ; then

  echo Maximum number of updates supported for all layouts : $ODB_NMXUPD

  ist=$(($ODB_NMXUPD+1))
  if [ $ist -le 9 ] ; then
    egrep -v "(update_[$ist-9].sql$|update_1[0-9].sql$)" $packlist > packlist.upd
  elif [ $ist -le 19 ] ; then
    ist=$((ist-10))
    grep -v "update_1[$ist-9].sql$)" $packlist > packlist.upd
  else
    echo odbstuffpack internal error : ODB_NMXUPD too large
    cd $GMKWRKDIR
    \rm -rf odbstuffpack
    exit 1
  fi
  sort -u $packlist > packlist.sorted
  sort -u packlist.upd > packlist.upd.sorted
  cmp -s packlist.sorted packlist.upd.sorted
  if [ $? -ne 0 ] ; then
    echo
    echo WARNING : removed unsupported update sql files :
    comm -23 packlist.sorted packlist.upd.sorted
    \mv packlist.upd $packlist
  fi

fi

grep "^${project}/.*\.ddl$" $packlist > ddlfiles.list

# move dummy static_init files to "unsatisfied external reference directory"
# ------------------------------------------------------------------------
#
if [ -s ddlfiles.list ] ; then
  unset EGREPLIST
  \rm -f dummystatic.list
  for element in $(cat ddlfiles.list) ; do
    label=$(basename $element .ddl)
    EGREPLIST=$(echo ${EGREPLIST}\|${label} | sed "s/^|//")
    egrep "($EGREPLIST)_static_init\.c$" $packlist | sort > dummystatic.list
  done
  if [ -s dummystatic.list ] ; then
    echo
    echo WARNING : the following precomputed dummy static_init files
    echo will be replaced by regular Sstatic dummies in the
    echo $GMKUNSX/$GMKUNSX_VERBOOSE directory:
    cat dummystatic.list
    for file in $(cat dummystatic.list) ; do
      locfile=$(basename $file)
      label=$(echo $locfile | cut -d"_" -f1)
      outfile=$TARGET_PACK/$GMKSRC/$GMKUNSX/$GMKUNSX_VERBOOSE/${label}_Sstatic.c
      echo "void ${label}_static_init() { printf(\"${label}_static_init : dummy subroutine by gmkpack\\\n\"); return; }" > $outfile
    done
    comm -23 $packlist dummystatic.list >  packlist.upd
    \mv packlist.upd $packlist
  else
# since odbglue, make then anyhow as a quick&dirty adaptation. later the 
# executables should come with configuration files telling which databases to link.
    echo
    echo WARNING : the following dummy static_init files
    echo will be computed beside odbglue as a temporary solution, in
    echo $GMKUNSX/$GMKUNSX_VERBOOSE directory:
    grep "\.ddl$" $packlist | sort -u | 
    for file in $(grep "\.ddl$" $packlist | sort -u) ; do
      label=$(basename $file .ddl)
      outfile=$TARGET_PACK/$GMKSRC/$GMKUNSX/$GMKUNSX_VERBOOSE/${label}_Sstatic.c
      echo "void ${label}_static_init() { printf(\"${label}_static_init : dummy subroutine by gmkpack\\\n\"); return; }" > $outfile
      echo ${label}_static_init.c
    done
# Add odbglue if needed : the action below is quite critical
# to find if the current release is older than CY32
# there should be an object file Codb_set_entrypoint.o after the compilation
    if [ $(grep -c "Codb_set_entrypoint\.c" $packlist) -ne 0 ] ; then
      echo Now ignored : Codb_set_entrypoint.c
      grep -v "Codb_set_entrypoint\.c" $packlist > packlist.upd
      \mv packlist.upd $packlist
    fi
  fi
fi

# So far we hope we have a clean list of files
cmp -s $packlist packlist.bak
if [ $? -ne 0 ] ; then
  echo
  echo odb final content :
  echo =================
  grep "^odb\/" $packlist
  echo
  \rm packlist.bak
fi
#
# Let's hope we have enough to compile the precompiler ...
export INCDIR_LIST=$MyTmp/incdirlist
$GMKROOT/aux/incdirpack.sh
if [ -s $INCDIR_LIST ] ; then
  echo "   temporary list of include directories for ODB precompiler preprocessing :"
  cat $INCDIR_LIST
fi
#
# Build precompiler if needed and absent :
# --------------------------------------
echo
if [ $(egrep -c "(\.ddl$|\.sql$)" $packlist) -ne 0 ] ; then
  if [ ! -f $ODB98NAME ] ; then
    echo Build precompiler odb98 ...
    $GMKROOT/aux/syspack.sh odb98
    if [ $? -ne 0 ] || [ ! -f $ODB98NAME ] ; then
      cd $GMKWRKDIR
      \rm -rf odbstuffpack
      exit 1
    fi
  fi    
fi

#
# "Expand" .ddl files if not up-to-date
# -------------------------------------
#
if [ -s ddlfiles.list ] ; then
  echo Process *.ddl files ...
  unset ODB_SETUP_FILE
  mkdir $MyTmp/local
  for element in $(cat ddlfiles.list) ; do
    object="${element}_"
    if [ ! -f $MKMAIN/$object ] || [ "$(find $MKMAIN -name "$element" -newer $MKMAIN/$object 2>/dev/null)" ] ; then
      db=$(dirname $element)
      file=$(basename $element)
#     Use of cpp enable to be anywhere, not specially where the include files are (we don t know where they are)
#
      if [ ! -f incdir ] ; then
#       Prepare to filter system directories
        for dir in \
          postodb \
          ddl.POSTODB \
          ddl.PREODB \
          prescreen \
          ddl.PRESCREEN \
          y2k.obsolete \
          examples \
          ddl \
          build \
          build_mf \
          compiler \
          scripts \
          doc \
          man \
          perl \
          bintmp \
          flags \
          odbsql \
          odbdummy \
          ; do
          echo odb/$dir >> sysdir
        done
        sort -u sysdir > sysdir.su
#       First let's find the include directories related to the current project:
        touch incdir.tmp
        \rm -f filtered_incdir
        for branch in $(cat $TARGET_PACK/.gmkview) ; do
          link=$(\ls -ld $MKTOP/$branch | $AWK '{print $NF}')
          for include in $(find $link/$project -name "*.h" -follow -depth -print 2>/dev/null) ; do
            dir=$(dirname $include)
            if [ $(grep -c $dir incdir.tmp) -eq 0 ] ; then
              echo $dir >> incdir.tmp
            fi
          done
          sort -u incdir.tmp >  incdir.tmp.su 
          comm -23 incdir.tmp.su sysdir.su >> filtered_incdir
        done
        sed "s/^/${MODINC}/g" filtered_incdir > incdir
        \rm -f filtered_incdir incdir.tmp sysdir.su
        cat incdir 2>/dev/null
      fi
#
      if [ $ICS_ECHO -le 1 ] ; then
        cpp_command="$VCCNAME -E -P -x c $MACROS_CC $GMK_CFLAGS_ODB $element"
        echo $cpp_command
      else
        cpp_command="$VCCNAME -E -P -x c $MACROS_CC $GMK_CFLAGS_ODB \ "
        echo $cpp_command
        cat $MyTmp/incdir 2>/dev/null | sed "s/$/ \\\/"
        echo $element
      fi
      \cp $MKMAIN/$element $file
      $VCCNAME -E -P -x c $MACROS_CC $GMK_CFLAGS_ODB $(echo $(cat incdir 2>/dev/null)) $file > $file.cpp
      if [ ! -s $file.cpp ] ; then
#       Looks like the "compiler didn't pre-process. Try again with another file extension :
        \ln -s $file ${file}.c
        $VCCNAME -E -P -x c -c $MACROS_CC $GMK_CFLAGS_ODB $(echo $(cat incdir 2>/dev/null)) ${file}.c > $file.cpp 2>/dev/null
	\rm ${file}.c
      fi
      chmod 644 $file
      \cp $file $file.bak
      \mv $file.cpp $file
      cd local
      \rm -f *
#     Search the latest compilation flags in the current database
      ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/$db/odb98.flags 2>/dev/null | head -1)
      if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#       Else, search the latest compilation flags in the general ddl directory
        ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/ddl/odb98.flags 2>/dev/null | head -1)
      fi
      if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#       Else, give a chance to any exotic directory :-(
        ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/*/odb98.flags 2>/dev/null | head -1)
      fi
      if [  "$ODB_COMPILER_FLAGS" ] ; then
        echo ODB_COMPILER_FLAGS is $ODB_COMPILER_FLAGS
        export ODB_COMPILER_FLAGS
      else
        cd $GMKWRKDIR
        \rm -rf odbstuffpack
        exit 1
      fi
      odb_command="$(echo $(basename $ODB98NAME)) $ODBFLAGS -o \$PWD $element"
      echo $odb_command
      eval $ODB98NAME $ODBFLAGS -o $PWD $MyTmp/$file 2>/dev/null
#     fetch back what has been created and update pack content :
      echo Add or update source files :
      for newfile in $(\ls *.ddl_ *.h *.c 2>/dev/null) ; do
        echo $db/$newfile | tee -a $packlist
        \mv $newfile $MKMAIN/$db
      done
      cd ..
      \mv $file.bak $file
    else
      echo $element is up-to-date.
    fi
  done
  egrep -v "(\.ddl$|\.ddl_$)" $packlist > mylist
  \mv mylist $packlist
fi
#
# Make/Update static stub files
# -----------------------------
#
cd $MyTmp
\rm -rf *
grep "^${project}/.*\.sql$" $packlist > sql_requests
\rm -f sql_requests_rejected
ERROR=0
if [ -s sql_requests ] ; then
  echo Make/update Stubb files with new\(er\) requests ...
  \rm -f database.list
  for file in $(cat sql_requests) ; do
    echo $(dirname $file) >> database.list
  done
  mkdir labelwork
  for db in $(sort -u database.list) ; do
#   File *.ddl_ MUST be present to run odb98.x
    ddl_file=$(\ls -1t $MKTOP/*/$db/*.ddl_ 2>/dev/null | head -1)
    if [ "$ddl_file" ] ; then
      label=$(basename $ddl_file .ddl_)
      \rm -f new.sql labelwork/* sql_newer_list
      \ln -sf $ddl_file labelwork/${label}.ddl_
      stubb_file=${label}_Sstatic.c
    fi
    if [ $(\ls -1 $MKTOP/*/$db/$stubb_file 2>/dev/null | wc -l) -ne 0 ] ; then
      last_stubb_file=$(\ls -1t $MKTOP/*/$db/$stubb_file | head -1)
      find $MKTOP/$GMKLOCAL/$db -name "*.sql" -newer $last_stubb_file -print 2>/dev/null 1> sql_newer_list
      if [ -s sql_newer_list ] ; then
        \cp $last_stubb_file labelwork/$stubb_file
#       Find new views (there might be more than one per sql file) not yet in existing stubb file :
        for file in $(cat sql_newer_list) ; do
          Number_of_views=$(egrep -c '^[ \t]*CREATE[ \t]+VIEW' $file)
          if [ $Number_of_views -eq 1 ] ; then
#           We assume what should be true (?) : view name = $(basename filename .sql)
            view=$(basename $file .sql)
            if [ $(grep -c "ODB_ANCHOR_VIEW(${label}, $view );" labelwork/$stubb_file) -eq 0 ] ; then
              if [ $ICS_ECHO -gt 1 ] ; then
                echo view $view absent
              fi
              \ln -s $file labelwork/$(basename $file)
            else
              if [ $ICS_ECHO -gt 1 ] ; then
                echo view $view present
              fi
            fi
          elif [ $Number_of_views -gt 1 ] ; then
#           We assume that the view name is the one to be "anchored".
            echo Warning : more than 1 view in file $(basename $file)
            for view in $(egrep '^[ \t]*CREATE[ \t]+VIEW' $file | sed 's/^[ \t]*//' | $AWK '{print $3}') ; do
              if [ $(grep -c "ODB_ANCHOR_VIEW(${label}, $view );" labelwork/$stubb_file) -eq 0 ] ; then
                  if [ $ICS_ECHO -gt 1 ] ; then
                    echo view $view absent
                  fi
                if [ ! -f $MyTmp/labelwork/$(basename $file) ] ; then
                  \ln -s $file labelwork/$(basename $file)
                fi
              else
                if [ $ICS_ECHO -gt 1 ] ; then
                  echo view $view present
                fi
              fi
            done
          fi
        done 
#       Increment stubb file with new sql requests :
        cd labelwork
#       Search the latest compilation flags in the current database
        ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/$db/odb98.flags 2>/dev/null | head -1)
        if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#         Else, search the latest compilation flags in the general ddl directory
          ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/ddl/odb98.flags 2>/dev/null | head -1)
        fi
        if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#         Else, give a chance to any exotic directory :-(
          ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/*/odb98.flags 2>/dev/null | head -1)
        fi
        if [  "$ODB_COMPILER_FLAGS" ] ; then
          echo ODB_COMPILER_FLAGS is $ODB_COMPILER_FLAGS
          export ODB_COMPILER_FLAGS
        else
          cd $GMKWRKDIR
          \rm -rf odbstuffpack
          exit 1
        fi
        sql_list=$(\ls *.sql 2>/dev/null)
        if [ "$sql_list" ] ; then
          echo "$(basename $ODB98NAME) $ODBFLAGS -i -s -S -w -l $label -o \$PWD $sql_list"
          for file in $sql_list ; do
            if [ $ICS_ECHO -le 2 ] ; then
              echo $file ...
              $ODB98NAME $ODBFLAGS -i -s -S -w -l $label -o $PWD $file 1>/dev/null
            else
              $ODB98NAME $ODBFLAGS -i -s -S -w -l $label -o $PWD $file
              if [ -s $(basename $file .sql).lst ] ; then
                cat $(basename $file .sql).lst
              elif [ -f $(basename $file .sql).lst ] ; then
                echo $(basename $file .sql).lst is empty.
              else
                echo no file $(basename $file .sql).lst
              fi
            fi
          done
          cmp -s $last_stubb_file $stubb_file 2>/dev/null
          code=$?
          if [ $code -eq 1 ] ; then
            echo Static stubb file $stubb_file has been updated from $last_stubb_file with the following lines :
            diff $stubb_file $last_stubb_file | grep "^<"
            \mv $stubb_file $MKMAIN/$db
            echo $db/$stubb_file >> $packlist
          else
            echo Static stubb file $last_stubb_file has NOT been updated.
          fi
        else
          echo No new views. Static stubb file $last_stubb_file is up-to-date.
        fi 
        cd ..
      else
        echo No newer requests. Static stubb file $last_stubb_file is up-to-date.
      fi
    else
      if [ "$stubb_file" ] ; then
#       Make a new static stubb file
#       Search the latest compilation flags in the current database
        ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/$db/odb98.flags 2>/dev/null | head -1)
        if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#         Else, search the latest compilation flags in the general ddl directory
          ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/ddl/odb98.flags 2>/dev/null | head -1)
        fi
        if [ ! "$ODB_COMPILER_FLAGS" ] ; then
#         Else, give a chance to any exotic directory :-(
          ODB_COMPILER_FLAGS=$(\ls -1t $MKTOP/*/odb/*/odb98.flags 2>/dev/null | head -1)
        fi
        if [  "$ODB_COMPILER_FLAGS" ] ; then
          echo ODB_COMPILER_FLAGS is $ODB_COMPILER_FLAGS
          export ODB_COMPILER_FLAGS
        else
          cd $GMKWRKDIR
          \rm -rf odbstuffpack
          exit 1
        fi
	echo "Generate Static stubb file ${stubb_file} ..."
        export SSTUBBFILENAME="$stubb_file"
	export REJECTED_SQL="sql_requests_rejected"
	export label
        cd labelwork
        for file in $(grep "^${db}/" ../sql_requests) ; do
          \ln -s $MKTOP/$GMKLOCAL/$file $(basename $file)
        done
        $GMKROOT/aux/Podbstubfile.sh 
        if [ -f $stubb_file ] ; then
          \mv $stubb_file $MKMAIN/$db
          echo $db/$stubb_file >> $packlist
          echo Static stubb file $stubb_file has been created.
        else
          echo "Static stubb file $stubb_file missed !"
          ERROR=1
        fi
      else
        echo "No label for this base !!!"
        ERROR=1
      fi
      cd ..
    fi
  done
  \rm -rf labelwork
# "Remove" .sql files not in static stubb files :
  if [ -s sql_requests_rejected ] ; then
    ERROR=1
    sort -u sql_requests_rejected > sql_requests_rejected.su
    sort -u sql_requests > sql_requests.su
    echo Rejected sql files because no c file generated :
    comm -12 sql_requests.su sql_requests_rejected.su
    comm -23 sql_requests.su sql_requests_rejected.su > sql_requests_valid
    grep -v "\.sql$" $packlist > mylist
    cat mylist sql_requests_valid > $packlist
  fi
fi
#
# Add directories containing *.c files in include list :
#
cd $MyTmp
touch incpath
cat $MKTOP/.incpath.local 1> incpath 2>/dev/null
for file in $(grep "\.c$" $packlist) ; do
  dir=$(dirname $file)
  if [ $(grep -c ^${MODINC}${MKTOP}/${GMKLOCAL}/${dir}$ incpath) -eq 0 ] ; then
    echo ${MODINC}${MKTOP}/${GMKLOCAL}/${dir} >> incpath
  fi
done
\mv incpath $MKTOP/.incpath.local
#
cd $GMKWRKDIR
\rm -rf odbstuffpack
if [ $ERROR -eq 1 ] ; then
  exit 1
fi
