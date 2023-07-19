#!/bin/bash
########################################################################
#
#    Script fypppack.sh
#    ---------------
#
#    Purpose : In the framework of a pack : driver to fypp in order to save the produced .F90 files
#    -------   preserving the stacking branches facility
#              .F90 files are stores inside the directory $GMKFYPPF90 of the local branch, following the
#              directory tree of the original .fypp file
#
#    Usage : fypppack.sh $1 $2 $3
#    -----
#            $1 (input)  : file list of .fypp or .yaml files to process
#            $2 (output) : file list of created or modified resulting .F90 files
#            $3 (output) : list of background modules directories not to be forgotten even if not re-modified
#
#    Environment variables :
#    ---------------------
#            GMKROOT        : gmkpack root directory
#            MKTOP          : directory of all source files
#            ICS_ECHO       : Verboose level
#            AWK            : awk
#            GMK_FYPP       : fypp program
#            GMK_FYPP_FLAGS : fypp external flags
#            GMKFYPPF90     : where to store the .F90 files inside the local branch
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

/bin/rm -f actual_preprocessed_files_list included_fyppfiles_list
touch actual_preprocessed_files_list included_fyppfiles_list

# 0/To avoid conflicting filenames, the process shoule be done project per project
# 1/Locate the latest python modules in the current project
# 2/For each local .yaml file, fetch the latest .fypp files using it
# 3/For each .hypp or .fypp file of the local branch, fetch it (if not already fetched) and fetch the latest .fypp files using it
# 4/Fetch recursively the included files which can be .hypp or .fypp files
# 5/Finally, process each .fypp file. Doing this, fetch on the fly the latest .yaml file used by the current .fypp

echo
for project in $(cat $1 | $AWK -F"/" '{print $1}' | sort -u) ; do

  echo "in project $project :"
# Reset the list of input actualized fypp files :
  /bin/rm -f actual_fyppfiles_list
  touch actual_fyppfiles_list
# /bin/rm any file created by a previous project
# unset any variable created by a previous project
  unset SPECIFIC_MODULES
  unset RELATIVE_SPECIFIC_MODULES

# Locate the latest python modules in this project :
# SPECIFIC_MODULES is what we need for pre-processing
# RELATIVE_SPECIFIC_MODULES is the equivalent but with relative path, just to monitor what we are doing
  for module in $(find $MKTOP/*/$project -type f -name "*.py" -follow| sed "s:$MKTOP::" | cut -d "/" -f4- | sort -u) ; do
    for branch in $(cat $TARGET_PACK/$GMK_VIEW) ; do
      py_file=$(find $MKTOP/$branch/$project/$(dirname $module) -name "$(basename $module)" -follow 2>/dev/null)
      if [ "$py_file" ] ; then
        SPECIFIC_MODULES="$SPECIFIC_MODULES -M $(dirname $py_file) -m $(basename $py_file .py)"
        RELATIVE_SPECIFIC_MODULES="$RELATIVE_SPECIFIC_MODULES -M $(echo $(dirname $py_file) | sed  "s:$MKTOP:~:") -m $(basename $py_file .py)"
	break
      fi
    done
  done
  
# For each of .yaml file of the local branch, fetch the latest .fypp files using it :
# However, .yaml files are passive ; therefore if they are not changed, they should be dropped.
# Important notice : .fypp files are such that they use .yaml file from the same directory.
# Consequently there can be many .yaml files with the same basename and located in different directories
# so that the links of .yaml files to the local directory must be made "on the fly", just before the fypp pre-processing.
  echo "Scanning local .yaml files ..."
  for yamlfile in $(grep "^${project}/.*\.yaml$" $1) ; do
    dir=$(dirname $yamlfile)
    name=$(basename $yamlfile)
    N=1
#   Locate the latest .yaml file in the current project :
    for branch in $(cat $TARGET_PACK/$GMK_VIEW | sed "1 d") ; do
      if [ -d $MKTOP/$branch/$dir ] ; then
        latest=$(find $MKTOP/$branch/$dir -type f -name "$name" -follow)
        if [ "$latest" ] ; then
#         A previous version of the .hypp exists, compare it with the new one:
          cmp -s $latest $MKMAIN/$yamlfile
          N=$?
          break
        fi
      fi
    done
    if [ $N -eq 0 ] ; then
#     skip this file
      echo "skipping unchanged file $yamlfile"
      continue
    fi
    for fyppfile in $(find $MKTOP/*/${dir} -name "*.fypp" -follow | xargs grep -l "/${name}" | awk -F "/" '{print $NF}' | sort -u) ; do
      for branch in $(cat $TARGET_PACK/$GMK_VIEW) ; do
        latestfile=$(find $MKTOP/$branch/${dir} -name "${fyppfile}" -follow)
	if [ "$latestfile" ] ; then
          /bin/ln -s ${latestfile} $fyppfile 2>/dev/null
	  echo "$fyppfile -> $branch/${dir}/${fyppfile}"
          echo "${dir}/$fyppfile" >> actual_fyppfiles_list
	  break
	fi
      done
    done
  done

  echo "Scanning local .[hf]ypp files ..."
# For each .hypp or .fypp file of the local branch, fetch it (if not already fetched) and fetch the latest .fypp files using it :
# However, .hypp files are passive ; therefore if they are not changed, they should be dropped.
  for Xyppfile in $(grep "^${project}/.*\.[hf]ypp$" $1) ; do
    dir=$(dirname $Xyppfile)
    name=$(basename $Xyppfile)
    N=1
    if [ "$(echo $name | $AWK -F "." '{print $NF}')" = "hypp" ] ; then
#     Locate the latest .hypp file in the current project :
      for branch in $(cat $TARGET_PACK/$GMK_VIEW | sed "1 d") ; do
        if [ -d $MKTOP/$branch/$dir ] ; then
          latest=$(find $MKTOP/$branch/$dir -type f -name "$name" -follow)
          if [ "$latest" ] ; then
#           A previous version of the .hypp exists, compare it with the new one:
            cmp -s $latest $MKMAIN/$Xyppfile
            N=$?
            break
          fi
        fi
      done
    fi
    if [ $N -eq 0 ] ; then
#     skip this file
      echo "skipping unchanged file $Xyppfile"
      continue
    fi
    if [ ! -f $name ] ; then
      /bin/ln -s $MKMAIN/$Xyppfile $name 2>/dev/null
      echo "$name -> $(basename $MKMAIN)/${Xyppfile}"
      if [ "$(echo $name | $AWK -F "." '{print $NF}')" = "fypp" ] ; then
        echo "$Xyppfile" >> actual_fyppfiles_list
      fi
    fi
    for fyppfile in $(find $MKTOP/* -name "*.fypp" -type f -follow | xargs grep -l ":include.*${name}" | $AWK -F "/" '{print $NF}' | sort -u) ; do
      for branch in $(cat $TARGET_PACK/$GMK_VIEW) ; do
        latestfile=$(find $MKTOP/$branch -name "${fyppfile}" -follow)
	if [ "$latestfile" ] ; then
	  if [ -f $latestfile ] ; then
            /bin/ln -s ${latestfile} $fyppfile 2>/dev/null
            latestversion=$(echo ${latestfile} | sed "s:^${MKTOP}/::")
	    echo "$fyppfile -> $latestversion"
#           the same, without the project name ahead :
            echo $latestversion | cut -d "/" -f2- >> actual_fyppfiles_list
	    break
	  fi
	fi
      done
    done
  done

# For each selected .[hf]ypp file, fetch the latest files included inside by the directive ":include" (if not already fetched)
# These files can be .fypp files (if not .hypp files), therefore a recursive loop is needed, until no additional file is fetched :
  echo "Scanning additional :included .[hf]ypp files ..."
  if [ $(find . -name "*.[hf]ypp" -type f -follow | wc -l) -ne 0 ] ; then
    REDO=1
    while [ $REDO -eq 1 ] ; do
      REDO=0
      for includename in $(grep -h ":include" *.[hf]ypp | cut -d '"' -f2 | sort -u) ; do
        if [ ! -f $includename ] ; then
          for branch in $(cat $TARGET_PACK/$GMK_VIEW) ; do
            N=$(find $MKTOP/$branch/$project -name "$includename" -type f -follow | wc -l)
	    if [ $N -gt 1 ] ; then
              echo "gmkpack problem : more than one \":include\" file detected :"
              find $MKTOP/$branch/$project -name "$includename" -type f -follow
              exit 1
            fi
            includefile=$(find $MKTOP/$branch/$project -name "$includename" -type f -follow)
            if [ "$includefile" ] && [ ! -f $includename ] ; then
              /bin/ln -s $includefile $includename 2>/dev/null
	      echo "${includename} -> $(echo $includefile | sed "s:^${MKTOP}/::")"
	      if [ "$(echo $includename | $AWK -F "." '{print $NF}')" = "fypp" ] ; then
                included_file=$(echo $includefile | sed "s:^${MKTOP}/::" | cut -d"/" -f2-)
                echo $included_file >> actual_fyppfiles_list
                echo $included_file >> included_fyppfiles_list
	      fi
	      REDO=1
	      break
            fi
          done
        fi
      done
    done
  fi

#  echo
  for fyppfile in $(cat actual_fyppfiles_list | sort -u) ; do

    dir=$(dirname $fyppfile)
    name=$(basename $fyppfile)

    echo
    echo "processing $name :"

#   F90 output file name :
    outdir=$MKTOP/$GMKLOCAL/$GMKFYPPF90/$dir
    outname=$(basename $fyppfile .fypp).F90
    F90file=$outdir/$outname
    mkdir -p $outdir

#   F90 temporary file name :
    F90tmpfile=./$outname

#   For each .fypp file, fetch the latest .yaml files used by it (they must be in the same directory)
#   Cleanup first, in case there are multiple files with the same basename (and there are, actually !) :
    /bin/rm -f *.yaml

    for yamlfile in $(grep -h ".*\.yaml" ${name} | awk -F "'" '{print $(NF-1)}' | sed "s:^/::" | sort -u) ; do
      for branch in $(cat $TARGET_PACK/$GMK_VIEW) ; do
        configfile=$(find $MKTOP/$branch/$dir -name "$yamlfile" -type f -follow)
        if [ "$configfile" ] ; then
          /bin/ln -s $configfile $yamlfile 2>/dev/null
          echo "$yamlfile -> $branch/$dir/$yamlfile"
          break
        fi
      done
    done

#   In short, what we do :
    echo "$GMK_FYPP $GMK_FYPP_FLAGS $RELATIVE_SPECIFIC_MODULES ./$name ~/$GMKFYPPF90/$dir/$outname"

#   Locate the latest corresponding F90 file in the current project :
    for branch in $(cat $TARGET_PACK/$GMK_VIEW) ; do
      if [ -d $MKTOP/$branch/$GMKFYPPF90/$dir ] ; then
        latest=$(find $MKTOP/$branch/$GMKFYPPF90/$dir -type f -name "$outname" -follow)
        if [ "$latest" ] ; then
          break
        fi
      fi
    done

#   Preprocess ("./" ahead of .fypp files is needed to tell that the corresponding .yaml files are in the current directory)
    eval $GMK_FYPP $GMK_FYPP_FLAGS $SPECIFIC_MODULES ./$name $F90tmpfile 1> fypp_report 2>&1
    if [ $? -ne 0 ] ; then
#     Report errors
      echo "fypp failed for file $name"
      if [ -s fypp_report ] ; then
        cat fypp_report
      fi
      /bin/rm -f fypp_report
      exit 1
    else
      if [ "$latest" ] ; then
        cmp -s $latest $(basename $F90tmpfile)
        N=$?
        if [ $N -eq 0 ] ; then
#         it is recompile time and the pre-processed local file (which can be a dependency) is up to date :
          echo "$F90file : no-change"
          if [ -f $F90file ] ; then
#           the latest file is up-to-date and present in local ;
#           and that file may have been brought by a dependency
            echo $GMKFYPPF90/$dir/$outname >> actual_preprocessed_files_list
#         else 
#           the latest file is an up-to-date dependency from a lower branch, nothing to do, then.
	  fi
          if [ -f $outdir/$(basename $F90file .F90).${MODEXT} ] ; then
#           Do not forget the corresponding module if it exists :
            echo ${MODINC}${outdir} >> $3
	  fi
        else
          echo "$F90file : updated"
          /bin/mv $F90tmpfile $F90file
          echo $GMKFYPPF90/$dir/$outname >> actual_preprocessed_files_list
        fi
      else
        /bin/mv $F90tmpfile $F90file
        echo "$F90file : created"
        echo $GMKFYPPF90/$dir/$outname >> actual_preprocessed_files_list
      fi
    fi

  done
  echo

done

#echo "actual preprocessed files list :"
#if [ -s actual_preprocessed_files_list ] ; then
#  cat actual_preprocessed_files_list
#else
#  echo "(empty)"
#fi

# No errors if we arrive at this stage :
/bin/cp actual_preprocessed_files_list $2

exit 0
