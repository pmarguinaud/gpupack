#!/bin/bash
########################################################################
#
#    Script lnkpack
#    --------------
#
#    Purpose : In the framework of a pack : to make  aset of binaries
#    -------
#
#    Usage : lnkpack
#    -----
#
#    Environment variables :
#    ---------------------
#            GMKWRKDIR    : main working directory
#            GMKROOT   : gmkpack root directory
#            MKLINK    : directory of binaries
#            MKLIB     : directory of libraries
#            GMKUNSX   : directory of unsatisfied external references
#
########################################################################
export LC_ALL=C

$GMKROOT/aux/licensepack.sh
if [ $? -ne 0 ] ; then
  exit 1
fi

MyTmp=$GMKWRKDIR/lnkpack
mkdir $MyTmp 2>/dev/null
find $MyTmp -name "*" -type f | xargs /bin/rm -f

# A dirty trick I will get rid of later :
export ICS_ERROR=$GMKWRKDIR/ics_error

if [ "$ICS_BL_GENERATOR" ] ; then
  if [ ! -f $ICS_BL_GENERATOR ] ; then
    unset ICS_BL_GENERATOR
  fi
fi

if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

if [ "$GMK_HUB_DIR" ] ; then
  HUB_GMKVIEW_FILE=$TARGET_PACK/$GMK_HUB_DIR/$GMK_VIEW
  if [ -s $HUB_GMKVIEW_FILE ] ; then
    $GMKROOT/aux/envvarpack.sh > $GMKWRKDIR/environment_variables
  fi
fi

echo
echo ------ Links editions -----------------------------------------------
\rm -f $MyTmp/missing_executables
target=$(uname -s | tr '[A-Z]' '[a-z]')
for binary in $(\ls -a $GMKWRKDIR 2> /dev/null | grep ^[.] | grep _link$ | cut -d"." -f2- | sed "s/_link$//") ; do
  /bin/rm -f $MyTmp/Myrpath $MyTmp/MySysLibs
  \rm -f $ICS_ERROR
  if [ -s $GMKWRKDIR/.${binary}_link ] ; then
    entry_point="$(grep ENTRY $GMKWRKDIR/.${binary}_link | cut -d"=" -f2)"
    executable=$(grep EXEC $GMKWRKDIR/.${binary}_link | cut -d"=" -f2)
    sharelib=$(echo $executable | $AWK -F "." '{print $NF}')
    if [ "$target" = "darwin" ] && [ "$sharelib" = "so" ] ; then
      loadmodule=$(basename $executable .so).dylib
      executable=$loadmodule
    fi
    if [ "$executable" ] ; then
      echo
      echo ========= Linking binary $executable =========
      echo
      if [ -d $HOME/.gmkpack/link/$binary ] ; then
        dir=$HOME/.gmkpack/link/$binary
      elif [ -d $GMK_SUPPORT/link/$binary ] ; then
        dir=$GMK_SUPPORT/link/$binary
      else
        dir=$GMKROOT/link/$binary
      fi
#     Select local libraries for this binary
      \rm -f $MyTmp/all_libs.list
#     Local libraries
      for project in $(cat $dir/projlist) ; do
        \ls -1 $GMKROOT/libs/$project 2> /dev/null | sort -u > $MyTmp/all_sections
        if [ -f $dir/excluded_libs/${project} ] ; then
          sort -u $dir/excluded_libs/${project} > $MyTmp/excluded_sections
          comm -23 $MyTmp/all_sections $MyTmp/excluded_sections > $MyTmp/sections 2> /dev/null
        else
          \mv $MyTmp/all_sections $MyTmp/sections
        fi
        for section in . $(cat $MyTmp/sections) ; do
          if [ "$section" = "." ] ; then
            section=""
          fi
          LIBRARY=${MKLIB}/lib${section}${project}.${GMKLOCAL}.a
          if [ -f $LIBRARY ] ; then
            echo "${LIBRARY}" >> $MyTmp/all_libs.list
          fi
        done
      done
#     Blacklist runtime library
      BL95NAME=$TARGET_PACK/$GMKSYS/bl95.x
      if [ -s $BL95NAME ] ; then
        BLACKLIST_CODE=$(cat $dir/blacklist 2>/dev/null)
        export BLACKLIST_CODE
        if [ "$BLACKLIST_CODE" ] ; then
#         Preprocessing via external script ; otherwise taken form source code:
          echo Blacklist runtime library:
          BLACKLIST=blacklist
          \rm -f $MyTmp/$BLACKLIST
          if [ "$ICS_BL_GENERATOR" ] ; then
            $ICS_BL_GENERATOR > $MyTmp/$BLACKLIST
            NEWEST_BLACKLIST=$MyTmp/$BLACKLIST
          else
            NEWEST_BLACKLIST=$(\ls -1t $(eval echo $MKTOP/*/$BLACKLIST_CODE) 2>/dev/null | head -1)
            if [ "$NEWEST_BLACKLIST" ] ; then
              if [ ! -s $NEWEST_BLACKLIST ] ; then
                unset NEWEST_BLACKLIST
              fi
            fi
            if [ "$NEWEST_BLACKLIST" ] ; then
              echo "File: $NEWEST_BLACKLIST"
              cd $MyTmp
#             In-situ preprocessing: 
              BL_PROJECT_NAME=$(basename $(dirname $NEWEST_BLACKLIST))
              unset BL_INCPATH
              for branch in $(cat $TARGET_PACK/$GMK_VIEW) ; do
                BL_INCPATH="${BL_INCPATH} -I${TARGET_PACK}/${GMKSRC}/${branch}/${BL_PROJECT_NAME}"
              done
#             To escape a "VCCNAME" which can be a compiler wrapper not able to act like a simple preprocessor,
#             change the name of the file to simulate a C code source file :
              \ln -s $NEWEST_BLACKLIST dummy_c_file.c
              eval $VCCNAME -E -P -x c $BL_INCPATH dummy_c_file.c > $BLACKLIST
              \rm dummy_c_file.c
            else
              echo "WARNING : non-existent or empty blacklist file \"${BLACKLIST_CODE}\" in pack"
            fi
          fi
#         Compilation:
          if [ -s $MyTmp/$BLACKLIST ] ; then
            cd $MyTmp
            rm -f *.a *.o *.h *.c
            export BL_GEN_C=yes
            export BL_CC="$VCCNAME"
            export BL_CFLAGS="$VCCFLAGS $MACROS_CC"
            $BL95NAME $BLACKLIST
            if [ -s C_code.o ] ; then
              LIBRARY=$MyTmp/libC_code.a
              $AR q $LIBRARY C_code.o
              if [ -f $LIBRARY ] ; then
                echo "${LIBRARY}" >> $MyTmp/all_libs.list
              else
                echo "ERROR : archive failed !"
              fi
            else
              if [ "$LD_USR07" ] ; then
                echo "WARNING : compilation failed ! The background library below will be used:"
                echo "$LD_USR07"
              else
                echo "ERROR : compilation failed !"
              fi
            fi
            cd ..
          else
            echo "ERROR : blacklist file \"${BLACKLIST}\" does not exist or is empty."
          fi
          echo
        fi
      fi
#     Dummies libraries
      for project in $(cat $dir/dummylist 2>/dev/null) ; do
        LIBRARY=${MKLIB}/libdummy${project}.${GMKLOCAL}.a
        if [ -f $LIBRARY ] ; then
          echo "${LIBRARY}" >> $MyTmp/all_libs.list
        fi
      done
#     Get bottom libraries :
      if [ -s $GMKWRKDIR/.${binary}_libs ] ; then
        $GMKROOT/aux/ggetpack.sh $(echo $(cat $GMKWRKDIR/.${binary}_libs))
        if [ -f $ICS_ERROR ] ; then
          \echo "Abort link."
          \echo $executable >> $MyTmp/missing_executables
        fi
      fi
      if [ ! -f $ICS_ERROR ] ; then
#       Backgroud libraries :
        for ulib in $(cat $GMKWRKDIR/.${binary}_libs 2>/dev/null) ; do
          echo $ulib >> $MyTmp/all_libs.list
        done
#       Add local unsatisfied external references libraries :
        for unsx in $GMKUNSX_VERBOOSE $GMKUNSX_QUIET ; do
          LIBRARY=${MKLIB}/lib${GMKUNSX}-${unsx}.${GMKLOCAL}.a
          if [ -f $LIBRARY ] ; then
            echo "${LIBRARY}" >> $MyTmp/all_libs.list
          fi
        done

#       Libraries from Hub :
#       if a library from hub found, take the one on top of the stack branch :
        if [ -s $HUB_GMKVIEW_FILE ] ; then
          echo "Libraries research in hub :"
          unset MyLastLibPath
          for VAR0 in $(cat $dir/hub_libs) ; do
            unset LIBFOUND_SHARED LIBFOUND_STATIC VAR
            VAR=$(grep "^export ${VAR0}=" $GMKWRKDIR/environment_variables | cut -d "=" -f2- | cut -d '"' -f2 | cut -d " " -f1)
	    if [ "$VAR" ] ; then
	      if [ "$(echo $VAR0 | cut -c1-4)" = "LNK_" ] ; then
#               This is an option to the linker, not a library :
                echo "$VAR" >> $MyTmp/MySysLibs
	      else
                for branch in $(echo $(cat $HUB_GMKVIEW_FILE | sed '1!G;h;$!d')) ; do
                  ACTUAL_HUB_BRANCH=$(\ls -ld $TARGET_PACK/$GMK_HUB_DIR/$branch | awk '{print $NF}')
                  for project in $(echo $GMK_HUB_PROJECTS) ; do
	            HUB_PROJECT=$ACTUAL_HUB_BRANCH/$GMK_HUB_INSTALL/$project
                    if [ -d $HUB_PROJECT ] ; then
                      FOUND=$(find $HUB_PROJECT/lib* \( -name "lib${VAR}.so" -o  -name "lib${VAR}.dylib" \) -follow)
                      if [ "$FOUND" ] ; then
                        LIBFOUND_SHARED=$FOUND
                      fi
                      FOUND=$(find $HUB_PROJECT/lib* -name "lib${VAR}.a" -follow)
                      if [ "$FOUND" ] ; then
                        LIBFOUND_STATIC=$FOUND
                      fi
                    fi
                  done
                done
                if [ "$LIBFOUND_SHARED" ] ; then
                  MyLibPath=$(dirname $LIBFOUND_SHARED)
                elif [ "$LIBFOUND_STATIC" ] ; then
                  MyLibPath=$(dirname $LIBFOUND_STATIC)
                fi
                if [ "$LIBFOUND_SHARED" ] || [ "$LIBFOUND_STATIC" ] ; then
                  echo "found $VAR in ${MyLibPath}"
                  if [ "$MyLibPath" != "$MyLastLibPath" ] ; then
                    echo "-L${MyLibPath} -l${VAR}" >> $MyTmp/MySysLibs
		  else
                    echo "-l${VAR}" >> $MyTmp/MySysLibs
                  fi
                  if [ "$LIBFOUND_SHARED" ] ; then
                    if [ -s $MyTmp/Myrpath ] ; then
                      if [ $(grep -c "${MyLibPath}" $MyTmp/Myrpath) -eq 0 ] ; then
                        echo "-Wl,-rpath,${MyLibPath}" >> $MyTmp/Myrpath
                      fi
                    else
                      echo "-Wl,-rpath,${MyLibPath}" >> $MyTmp/Myrpath
                    fi
                  fi
                  MyLastLibPath=${MyLibPath}
                else
                  echo "NOT FOUND: $VAR"
                fi
	      fi
	    fi
          done
          if [ -s $MyTmp/Myrpath ] ; then
#           insert the additional rpath ahead (ie before the ones from bottom system libraries) :
            sed "/-rpath/,$ d" $MyTmp/MySysLibs > $MyTmp/MySysLibs_top
            sed "1,/-rpath/ d" $MyTmp/MySysLibs > $MyTmp/MySysLibs_bottom
            grep "\-rpath"    $MyTmp/MySysLibs | head -1 > $MyTmp/MySysLibs_middle
            cat $MyTmp/MySysLibs_top $MyTmp/Myrpath $MyTmp/MySysLibs_middle $MyTmp/MySysLibs_bottom > $MyTmp/MySysLibs
            /bin/rm $MyTmp/MySysLibs_top $MyTmp/Myrpath $MyTmp/MySysLibs_middle $MyTmp/MySysLibs_bottom
          fi
        fi
#       Add system libraries at bottom of the list :
        if [ -s $GMKWRKDIR/.${binary}_sys ] ; then
          cat $GMKWRKDIR/.${binary}_sys >> $MyTmp/MySysLibs 
          echo
        fi
        echo
#       $1 : leading object files
#       $2 : ordered list of libraries
#       $3 : binary name
#       $4 : ordered list of system libraries
#       $5 : loader name and loading options
#       $6 : "ODBGLUE" if needed
        if [ $(grep -ch odb $dir/projlist 2>/dev/null) -eq 0 ] ; then
          $GMKROOT/aux/loadpack.sh "$entry_point" $MyTmp/all_libs.list $MKLINK/$executable $MyTmp/MySysLibs $GMKWRKDIR/.${binary}_load "NOGLUE"
        else
          $GMKROOT/aux/loadpack.sh "$entry_point" $MyTmp/all_libs.list $MKLINK/$executable $MyTmp/MySysLibs $GMKWRKDIR/.${binary}_load "ODBGLUE"
        fi
        if [ -f $ICS_ERROR ] ; then
          \echo "Abort load."
          \echo $executable >> $MyTmp/missing_executables
        fi
      fi
    fi
  fi
done

if [ -s $MyTmp/missing_executables ] ; then
  \echo "Links editions failed for the following executables:"
  \echo $(cat $MyTmp/missing_executables)
  exit 1
fi

exit 0
