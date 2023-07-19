#!/bin/bash
########################################################################
#
#    Script hubpack.sh
#    -----------------
#
#    Purpose : In the framework of a pack : to build side libraries
#    -------   with their own build scripts, prior to the compilation
#              of the source code itself.
#
#    Usage : hubpack.sh
#    -----
#
#    Environment variables :
#    ---------------------
#
#    GMK_HUB_PROJECTS   : list of projects.
#                         Projects are supposed to be ordered by dependencies.
#                         All libraries of a given project will be installed in a common project directory.
#                       : Each project has its own installation type (cmake & make, or configure & make, etc)
#    GMK_HUB_LIBRARIES_IN_${project} : ordered list of libraries to build for each project
#    GMK_HUB_BUILD      : Build directory name for a given library (absolute path)
#    GMK_HUB_INSTALL    : General install directory (common for all projects)
#    TARGET_PACK        : pack name
#    GMKWRKDIR          : leading working directory
#    GMK_RECONFIGURE    : ON/OFF to reconfigure even if the build directory exists, or not.
#    GMK_MAKE           : ON/OFF to compile (make) or not
#    GMK_TEST           : ON/OFF to perform tests or not
#    GMK_TEST_LIBRARIES_IN_${project} : list of libraries to test for each project
#    GMK_INSTALL        : ON/OFF to install libraires or not
#    GMK_CMAKE          : cmake executable
#
#    Method :
#    ------
#      Libraries are build following the options set in the configuration file.
#      These options are evaluated, therefore gmkpack overall compiler option can be used.
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

/bin/rm -rf $GMKWRKDIR/hubpack
mkdir $GMKWRKDIR/hubpack
cd $GMKWRKDIR/hubpack

if [ ! "$(\ls -1t $TARGET_PACK/.gmkfile 2>/dev/null | tail -1)" ] ; then
  echo "Error : no configuration file could be found in source pack."
  /bin/rm -rf $GMKWRKDIR/hubpack
  exit 1
fi

HUBLOCAL=$TARGET_PACK/$GMK_HUB_DIR/$GMKLOCAL

# Default cmake/ctest if not specified
if [ ! "$GMK_CMAKE" ] ; then
  GMK_CMAKE=cmake
  GMK_CTEST=ctest
elif [ "$GMK_CMAKE" = "cmake" ] ; then
  GMK_CTEST=ctest
else
  CTESTDIRNAME=$(dirname $GMK_CMAKE)
# I expect such adaptation as 'cmake3' to be interpreted as ctest to be replaced by ctest3
  CTESTBASENAME=$(echo $(basename $GMK_CMAKE) | sed "s/cmake/ctest/")
  if [ "$CTESTDIRNAME" ] ; then
    GMK_CTEST=$CTESTDIRNAME/$CTESTBASENAME
  else
    GMK_CTEST=$CTESTBASENAME
  fi
fi

for project in $(eval echo $GMK_HUB_PROJECTS) ; do
  if [ "$(eval echo \$GMK_HUB_METHOD_FOR_${project})" = "cmake" ] ; then
    for library in $(eval echo \$GMK_HUB_LIBRARIES_IN_${project}) ; do
      SOURCE_CODE=$HUBLOCAL/$GMKSRC/${project}/${library}
      if [ -d $SOURCE_CODE ] || [ -h $SOURCE_CODE ] ; then
        echo "================================================================================"
        echo
        echo "Start building $library from project $project :"
        echo
        BUILD_DIRECTORY=$(eval echo $GMK_HUB_BUILD/${library})
        ARGS=GMK_CMAKE_${library}
        EVALED_ARGS="$(eval echo \$$ARGS)"
#       Dynamic evaluation of magic variable GMK_LAST_HUB_BRANCH for each concerned argument :
        for equation in $(echo $EVALED_ARGS | tr " " "\n") ; do
	  if [ $(echo $equation | grep -c GMK_LAST_HUB_BRANCH) -eq 0 ] ; then
            if [ ! -f evaled_args_file ] ; then
              echo "$equation" > evaled_args_file
            else
              echo "$equation" >> evaled_args_file
            fi
          else
            var=$(echo $equation | cut -d "=" -f1)
	    enigma=$(echo $equation | cut -d "=" -f2-)
            for branch in $(cat $TARGET_PACK/$GMK_HUB_DIR/$GMK_VIEW) ; do
              GMK_LAST_HUB_BRANCH=$branch
	      solution=$(eval echo $enigma | tr " " "\n")
	      if [ -d $solution ] ; then
                echo "${var}=${solution}" >> evaled_args_file
	        break
              fi
            done
          fi
        done
	EVALED_ARGS=$(echo $(cat evaled_args_file))
	/bin/rm -f evaled_args_file
        IREP=0
        if [ -d $BUILD_DIRECTORY ] && [ "$GMK_RECONFIGURE" = "OFF" ] ; then
          echo "Notice : build directory already exists : ${BUILD_DIRECTORY}. No re-configure"
          cd $BUILD_DIRECTORY
          IREP=0
        else
          if [ -d $BUILD_DIRECTORY ] ; then
            /bin/rm -rf $BUILD_DIRECTORY
          fi
          mkdir -p $BUILD_DIRECTORY
#         (remove problematic option "-c")
          CMAKE_OPT_INSTALL="-DCMAKE_INSTALL_PREFIX=$HUBLOCAL/$GMK_HUB_INSTALL/${project}"
          CMAKE_COMMAND="$GMK_CMAKE $CMAKE_OPT_INSTALL $(echo "$EVALED_ARGS"  | sed -e "s/\"-c /\"/g" -e  "s/ -c / /g") $SOURCE_CODE"
          cd $BUILD_DIRECTORY
          echo $(eval echo $CMAKE_COMMAND)
          eval "$CMAKE_COMMAND"
          IREP=$?
        fi
        if [ $IREP -ne 0 ] ; then
          echo
          echo "Stopped while configuring $library"
          echo "See build directory : $PWD"
          echo "THEN DESTROY IT BEFORE RE-TRYING"
          exit 1
        else
          if [ "$GMK_MAKE" = "ON" ] ; then
            make -j $GMK_THREADS
            IREP=$?
            if [ $IREP -ne 0 ] ; then
              echo
              echo "Stopped while making $library"
              echo "See build directory : $PWD"
              echo "THEN DESTROY IT BEFORE RE-TRYING"
              exit 1
            fi
          else
            echo "Compilation disabled"
            IREP=0
          fi
          if [ $IREP -eq 0 ] ; then
            if [ "$GMK_TEST" = "ON" ] ; then
#             Find if the library is in the list of tested libraries
              for testlibrary in $(eval echo \$GMK_TEST_LIBRARIES_IN_${project}) ; do
                if [ "$library" = "$testlibrary" ] ; then
                  eval $GMK_CTEST
                fi
              done
            else
              echo "Tests disabled"
            fi
            if [ "$GMK_INSTALL" = "ON" ] ; then
              make install
              IREP=$?
              if [ $IREP -eq 0 ] ; then
                echo "$library installed."
                cd ..
              else
                echo
                echo "Stopped while installing $library"
                echo "See build directory : $PWD"
                echo "THEN DESTROY IT BEFORE RE-TRYING"
                exit 1
              fi 
              THIS_DIR=$PWD
              SHARELIBDIR="$(echo $(find $HUBLOCAL/$GMK_HUB_INSTALL/$project \
                \( -name "lib${library}*.so" -o -name "lib${library}*.dylib" \) -follow))"
              if [ "$SHARELIBDIR" ] ; then
#               complete with possibly missing static libraries :
                if [ $(echo "$EVALED_ARGS" | grep -ci "\-DBUILD_SHARED_LIBS=BOTH") -ne 0 ] || \
                   [ $(echo "$EVALED_ARGS" | grep -ci "\-DBUILD_SHARED_LIBS=OFF") -ne 0 ] ; then
                  echo "Verify that all static libraries have been created :"
                  for lib in $SHARELIBDIR ; do
                    LIBDIR=$(dirname $lib)
                    libstatic=$(echo $(basename $lib) | sed -e "s:^./::" -e "s:.so$:.a:" -e s":.dylib$:.a:")
                    cd $LIBDIR
                    if [ ! -f $libstatic ] ; then
                      echo "$libstatic is missing, create it now :"
                      radical=$(echo $libstatic | sed -e "s/^lib//" -e "s/.a$//")
                      if [ $(echo $radical | grep -c "_") -ne 0 ] ; then
                        dir=$(echo $radical | sed "s:_:/:")
                        cd $BUILD_DIRECTORY/src/$dir
                        linkfile=CMakeFiles/${radical}.dir/link.txt
                      else
                        cd $BUILD_DIRECTORY/src/$radical
                        linkfile=CMakeFiles/${radical}.dir/link.txt
                      fi
                      $AR qv $LIBDIR/$libstatic $(cat $linkfile | tr " " "[\012*]" | grep "\.o$")
                      cd $LIBDIR
                    fi
                  done
                fi
                cd $THIS_DIR
              fi
            else
              echo "Installation disabled"
            fi
          fi 
        fi
        echo
      else
        echo "No source code for $SOURCE_CODE"
      fi
    done
  fi
done
echo "================================================================================"

exit 0
