#!/bin/bash
########################################################################
#
#    Script syspack.sh
#    -------------------
#
#    Purpose : In the framework of a pack : to build the system programs
#    -------   prior to any compilation  (mainly : odb !)
#
#    Usage : syspack.sh $1
#    -----
#             $1 ; precompiler name
#
#    Environment variables :
#    ---------------------
#
#           GMKSRC
#           GMKBIN
#           GMKSYS
#           GMKROOT
#           CCNATIVE
#           MACROS_ODB98
#           MODINC
#           ICS_LIST
#           LIST_EXTENSION
#
########################################################################
#
export LC_ALL=C
if [ "$ZSH_NAME" = "zsh" ] ; then
  setopt +o nomatch
fi

MyTmp=$GMKWRKDIR/syspack
mkdir $GMKWRKDIR/syspack
cd $GMKWRKDIR/syspack
if [ ! "$1" ] ; then
    echo "NO PRECOMPILER NAME ! NOT BUILT."
    cd $GMKWRKDIR
    \rm -rf syspack
    echo Abort job.
    exit 1
else
  echo
  echo ------ Build $1.x -----------------------------------
  echo
fi
#
# First we copy the source code to the local directory :
# ----------------------------------------------------
#
unset srcdir_inc srcdir_aux
if [ "$1" = "odb98" ] ; then
  if [ -d $MKMAIN/odb/compiler ] ; then
    srcdir=$MKMAIN/odb/compiler
  elif [ -d $MKMAIN/odb/odbsql ] ; then
    srcdir=$MKMAIN/odb/odbsql
  else
    echo "No source code directory found for $1 !!"
    cd $GMKWRKDIR
    \rm -rf syspack
    echo Abort job.
    exit 1
  fi  
  CPPMACROS="$MACROS_ODB98"
# In case it would be useful ...
  export ODB_SETUP_SHELL=$SHELL
elif  [ "$1" = "bl95" ] ; then
  if [ -d $MKMAIN/bla/compiler ] ; then
#   Meteo-France naming convention
    srcdir=$MKMAIN/bla/compiler
    srcdir_aux=$MKMAIN/bla/library
    srcdir_inc=$MKMAIN/bla/include
  elif [ -d $MKMAIN/bl/compiler ] ; then
#   ECMWF naming convention
    srcdir=$MKMAIN/bl/compiler
    srcdir_aux=$MKMAIN/bl/library
    srcdir_inc=$MKMAIN/bl/include
  elif [ -d $MKMAIN/blacklist/compiler ] ; then
#   GCO naming convention
    srcdir=$MKMAIN/blacklist/compiler
    srcdir_aux=$MKMAIN/blacklist/library
    srcdir_inc=$MKMAIN/blacklist/include
  else
    echo "No source code directory found for $1 !!"
    cd $GMKWRKDIR
    \rm -rf syspack
    echo Abort job.
    exit 1
  fi
  CPPMACROS="$MACROS_BL95"
else
  echo "Unknown $1 !!"
  cd $GMKWRKDIR
  \rm -rf syspack
  echo Abort job.
  exit 1
fi
#
if [ $(\ls -1 $srcdir | wc -l) -eq 0 ] ; then
  echo "No source code below $srcdir !!"
  cd $GMKWRKDIR
  \rm -rf syspack
  echo Abort job.
  exit 1
else
  echo "Source code linked from $srcdir to temporary directory:"
  for file in $(\ls $srcdir) ; do
    echo $file
    \ln -s $srcdir/$file $file
  done
  if [ "$srcdir_aux" ] ; then
# dirty fix, isnt't it ?
    for file in $(\ls -1 $srcdir_aux | grep "^numarg_error.c$") ; do
      echo $file
      \ln -sf $srcdir_aux/$file $file
    done
  fi    
  if [ "$srcdir_inc" ] ; then
    for file in $(\ls -1 $srcdir_inc | grep "\.h$") ; do
      echo $file
      \ln -s $srcdir_inc/$file $file
    done    
  fi    
fi

SYSDIR=$TARGET_PACK/$GMKSYS/$1
mkdir -p $SYSDIR 2>/dev/null
#
# This block will add include path coming form the hub :
if [ "$INCDIR_LIST" ] ; then
  if [ -s $INCDIR_LIST ] ; then
    INCLUDE="$(echo $(cat $INCDIR_LIST | sed "s/^/${MODINC}/")) ${MODINC}."
  else
    INCLUDE=${MODINC}.
  fi
else
  INCLUDE=${MODINC}.
fi

LDFLAGS="$LD_LIBC $LD_LIBM $LD_LIBVFL"
INCLUDE="$INCLUDE $LDFLAGS"
# Not to mention the hub :
if [ "$GMK_HUB_DIR" ] ; then
  if [ -s $TARGET_PACK/$GMK_HUB_DIR/$GMK_VIEW ] ; then
    /bin/rm -f $MyTmp/Myrpath
    unset MyLastLibPath
    for VAR in $(echo "$LDFLAGS" | tr " " "\n" | sed "s/^-l//") ; do
      for branch in $(echo $(cat $TARGET_PACK/$GMK_HUB_DIR/$GMK_VIEW | sed '1!G;h;$!d')) ; do
        for project in $(echo $GMK_HUB_PROJECTS) ; do
          if [ -d $TARGET_PACK/$GMK_HUB_DIR/$branch/$GMK_HUB_INSTALL/$project ] ; then
            FOUND=$(find $TARGET_PACK/$GMK_HUB_DIR/$branch/$GMK_HUB_INSTALL/$project \
            \( -name "lib${VAR}.so" -o  -name "lib${VAR}.dylib" \) -follow)
            if [ "$FOUND" ] ; then
              LIBFOUND_SHARED=$FOUND
            fi
            FOUND=$(find $TARGET_PACK/$GMK_HUB_DIR/$branch/$GMK_HUB_INSTALL/$project -name "lib${VAR}.a" -follow)
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
          if [ -s $MyTmp/MySysLibs ] ; then
            sed "s:-l${VAR}:-L${MyLibPath} -l${VAR}:" $MyTmp/MySysLibs > $MyTmp/MySysLibs.new
            /bin/mv $MyTmp/MySysLibs.new $MyTmp/MySysLibs
	  else
# FIRST SYSTEM LIBRARY :-)
            echo "-L${MyLibPath} -l${VAR}" > $MyTmp/MySysLibs
          fi
        fi
        if [ "$LIBFOUND_SHARED" ] ; then
          echo "-Wl,-rpath,${MyLibPath}" >> $MyTmp/Myrpath
        fi
        MyLastLibPath=${MyLibPath}
      fi
    done
    if [ -s $MyTmp/Myrpath ] ; then
      sort -u $MyTmp/Myrpath >> $MyTmp/MySysLibs
    fi
  fi
fi
if [ -s $MyTmp/MySysLibs ] ; then
  LDFLAGS="$(echo $(cat $MyTmp/MySysLibs)) $LDFLAGS"
fi

# 1. Bison :
# --------
#
echo
\rm -f object.list
for file in $(\ls *.y 2>/dev/null) ; do
# For compatibility with yacc, old-style names are kept in the source code while we compile with bison
# so we should keep these names :
  object=$SYSDIR/y.tab.c
  if [ ! -f $object ] || [ "$(find $srcdir -name "$file" -newer "$object" -print 2>/dev/null)" ] ; then
    echo bison -d $file
    bison -d $file
    /bin/cp -p yacc.tab.h y.tab.h 2>/dev/null
    /bin/cp -p yacc.tab.c y.tab.c 2>/dev/null
    \cp -p $(basename $object c)* $(dirname $object) 2> /dev/null
  else
    echo up-to-date : $object
    echo "Source code linked to temporary directory:"
    echo $(basename $object c)h
    echo $(basename $object)
    /bin/ln -s $(dirname $object)/$(basename $object c)h $(basename $object c)h
    /bin/ln -s $(dirname $object)/$(basename $object) $(basename $object)
  fi
  echo $object >> object.list
done
#
# 2. LEXical language :
# -------------------
#
if [ "$1" = "odb98" ] ; then
# if flex is used, consider using flexfix :
  LEX_EXE=$(echo "$LEX" | cut -d " " -f1 | sed "s/ //g")
  LEX_ACTUAL_EXE=$(basename $($LEX_EXE --version | cut -d " " -f1))
  for file in $(\ls *.l 2>/dev/null) ; do
    object=$SYSDIR/lex.yy.c
    if [ ! -f $object ] || [ "$(find $srcdir -name "$file" -newer "$object" -print 2>/dev/null)" ] ; then
      if [ "$LEX_ACTUAL_EXE" = "flex" ] ; then
        export FLEX_EXE=$LEX_EXE
        lex_command="$GMKROOT/aux/flexfix.sh -l -v $file"
      else
        lex_command="$LEX -v $file"
      fi
      echo $lex_command
      eval $lex_command
      \cp -p $(basename $object) $(dirname $object) 2> /dev/null
      if [ "$LEX_ACTUAL_EXE" = "flex" ] ; then
#       test on the fly if the compilation will be successfull :
        newfile=$object
        newobject=$SYSDIR/$(basename $newfile .c).o
        c_command="$CCNATIVE -c $CPPMACROS $INCLUDE $newfile"
        echo "test compilation of $(basename $newfile) :"
        #echo $c_command
        eval $c_command
        if [ -f $(basename $newobject) ] ; then
          echo "compilation is successful with flexfix"
          \rm $(basename $newobject)
        else
          echo "compilation fails with flexfix, return to $LEX_EXE :"
          lex_command="$LEX -v $file"
          echo $lex_command
          eval $lex_command
          \cp -p $(basename $object) $(dirname $object) 2> /dev/null
          echo "test compilation of $newfile :"
          echo $c_command
          eval $c_command
          if [ -f $(basename $newobject) ] ; then
            echo "compilation is successful with $LEX_EXE"
            \rm $newobject
          else
            echo "compilation fails with $LEX_EXE, too. Another lexical analyser should be used."
          fi
        fi
      fi
    else
      echo up-to-date : $object
      echo "Source code linked to temporary directory:"
      echo $(basename $object)
      /bin/ln -s $(dirname $object)/$(basename $object) $(basename $object)
    fi
    echo $object >> object.list
  done
else
  for file in $(\ls *.l 2>/dev/null) ; do
    object=$SYSDIR/lex.yy.c
    if [ ! -f $object ] || [ "$(find $srcdir -name "$file" -newer "$object" -print 2>/dev/null)" ] ; then
      lex_command="$LEX -v $file"
      echo $lex_command
      eval $lex_command
      \cp -p $(basename $object) $(dirname $object) 2> /dev/null
    else
      echo up-to-date : $object
      echo "Source code linked to temporary directory:"
      echo $(basename $object)
      /bin/ln -s $(dirname $object)/$(basename $object) $(basename $object)
    fi
    echo $object >> object.list
  done
fi

# 3. C compilation :
# ----------------
#
\rm -f errorlist
for file in $(cat object.list 2>/dev/null) ; do
  if [ ! -f $file ] ; then
    echo $file >> errorlist
  fi
done
\rm -rf errorlog
if [ -s errorlist ] ; then
  echo PRE-COMPILATION ERROR\(S\) REPORTED IN : >> errorlog
  cat errorlist >> errorlog
else
  \rm -f object.list
  for file in $(\ls *.c 2>/dev/null) ; do
    object=$SYSDIR/$(basename $file .c).o
    if [ ! -f $object ] || \
       [ "$(find $srcdir $SYSDIR -name "$file" -newer "$object" -print 2>/dev/null)" ] || \
       [ "$(find $srcdir_aux $SYSDIR -name "$file" -newer "$object" -print 2>/dev/null)" ] \
     ; then
      c_command="$CCNATIVE -c $CPPMACROS $INCLUDE $file"
      echo $c_command
      eval $c_command
      \cp -p $(basename $object) $list $(dirname $object) 2> /dev/null
    else
      echo up-to-date : $object
    fi
    echo $object >> object.list
  done
  \rm -f errorlist
  for file in $(cat object.list 2>/dev/null) ; do
    if [ ! -f $file ] ; then
      echo $file >> errorlist
    fi
  done
fi
#
# Archive library & links :
# -----------------------
#
echo
if [ -s errorlist ] ; then
  echo COMPILATION ERROR\(S\) REPORTED IN : >> errorlog
  cat errorlist >> errorlog
  cat errorlog
  cd $GMKWRKDIR
  \rm -rf syspack
  echo Abort job.
  exit 1
else
  cd $SYSDIR
  arlib=lib$1.a
  if [ ! -f $arlib ] ; then
    $ARNATIVE -qv lib$1.a *.o
  elif [ "$(find . -name "*.o" -newer "$arlib" -print 2>/dev/null)" ] ; then
    $ARNATIVE -rv lib$1.a *.o
  else
    echo up-to-date : $arlib
  fi
fi
#
echo
for program in $1.x ; do
  PROGRAM=$TARGET_PACK/$GMKSYS/$program
  if [ ! -f $PROGRAM ] || [ "$(find . -name "$arlib" -newer "$PROGRAM" -print 2>/dev/null)" ] ; then
    \rm -f $PROGRAM
    ld_command="$CCNATIVE $LNK_MPCCNATIVE"
    entry="$1.o"
    ld_command="$ld_command -o $PROGRAM $entry -L. -l$1 $LDFLAGS"
    echo $ld_command
    eval $ld_command
    if [ ! -f $PROGRAM ] ; then
      echo program $1.x NOT BUILT.
      cd $GMKWRKDIR
      \rm -rf syspack
      echo Abort job.
      exit 1
    else
      echo
      echo $program created.
      echo
    fi 
  else
    echo up-to-date : $program
  fi
done
#
cd $GMKWRKDIR
\rm -rf syspack
