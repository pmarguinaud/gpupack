#!/bin/bash
#
# Tries to fix "flex" problems
#
# Instead of using
# flex -lv lex.l
# flex -l -v lex.l
#
# use
# flexfix -l -v lex.l
#
# Note: Some flex'es do not even understand "-lv", but "-l -v" !!
#
# You can try out different flex-executables, by redefining
# environment variable FLEX_EXE first. By default it is defined as:
#
# export FLEX_EXE=flex
#
#-- flex from version 2.5.33 (as far as I know/have been told)
#   stopped correctly parsing our lex.l
#
#   There were two major show-stoppers, real time-bombs:
#
#   1) %s MACRONAME 
#
#      generated to the C-code (= lex.yy.c i.e. lex.c)
#
#      #define MACRONAME <value>
#
#      AFTER where the macro had already been referred to!!
#
#   2) Not all the %-vars (sizing params for lex) followed by a number were understood, f.ex.:
#      %p 30000
#      %a 15000
#      %n 5000
#      %e 7000
#      %o 8000
#      %k 2500
#
#      And these used to be fundamental for successful lex-parsing
#
#   In addition embedded C-source code that was in the MIDDLE of the lex.l file
#   -- correctly quoted between %{ and %} was totally messed up
#
#-- So something very weird has happened and all lex-files
#   that Me, Myself & Irene created over the last decade were screwed up
#   in a totalitarian way !!
#
#-- Fixing it now !! (18-Feb-2008/SS)
#

export LC_ALL=C

set -eu

if [[ $# -lt 1 ]] ; then
  echo "Usage: $0 [flex_options] lex.l" >&2 
  exit 1
fi

export FLEX_EXE=${FLEX_EXE:=flex}

flex=$FLEX_EXE
flexbase=$(basename $flex)

cmd="$flex $*"
if [[ "$flexbase" != "lex" ]] ; then # ignore pure [old] "lex"
  screwed=205033 # screwed up versions begin (...apparently; you may have to change this downwards)

  vers=$($flex --version | awk '{print $NF}' | awk -F. '{printf("%d%2.2d%3.3d\n",$1,$2,$3)}')

  if [[ $vers -ge $screwed ]] ; then
    #-- This is indeed a screwed up version 
    args=""
    lastarg=""
    for x in $*
    do
      args="$args$x "
      lastarg=$x
    done
    new_lastarg=$lastarg.$$
    perl -ne 'print if (!m/^%([a-z])\s+\d+/)' $lastarg > $new_lastarg
    args=$(echo "$args" | perl -pe "s/$lastarg"'\s*$'"/$new_lastarg/")
    cmd="$flex $args"
  fi
fi

rc=0
$cmd || rc=$?
 
if [ $rc -eq 0 ] 
then 
   grep '^#define LEX_' lex.yy.c > a$$ 
   sed -e '/^#define LEX_/d' lex.yy.c > b$$ 
   cat a$$ b$$ > lex.yy.c 
   rm a$$ b$$ 
fi

exit $rc
