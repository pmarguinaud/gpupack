#!/bin/bash
#
# Usage: create_odbglue [dbname(s)]
#
# Creates glue-file "_odb_glue.c" and compiles it, if
# environment variable "ODB_CC" has been defined
#
# Author: Sami Saarinen, ECMWF, 13-Feb-2004
#                               11-Apr-2006 : No more known/predefined databases
#
#

export LC_ALL=C

set -eu

if [[ $# -lt 1 ]] ; then
  echo "Usage: create_odbglue [dbname(s)]" >&2
  exit 1
fi

odbglue=_odb_glue.c

cat > $odbglue << 'EOF'
#include <stdio.h>
#include <string.h>

extern void
codb_procdata_(int *myproc,
               int *nproc,
               int *pid,
               int *it,
               int *inumt);

extern void 
ODB_add2funclist(const char *dbname,
   void (*func)(),
                 int funcno);

#define Static_Init(db) \
if (strncmp(dbname, #db, dbname_len) == 0) { \
  extern void db##_static_init(); \
  ODB_add2funclist(#db, db##_static_init, 0); \
} \
else { /* fprintf(stderr,"***Warning: Not initializing '%s'\n",#db); */ }  

void
codb_set_entrypoint_(const char *dbname
              /* Hidden arguments */
              , int dbname_len)
{
  int myproc = 0;
  codb_procdata_(&myproc, NULL, NULL, NULL, NULL);
  if (myproc == 1) {
    fprintf(stderr,
            "codb_set_entrypoint_(dbname='%*s', dbname_len=%d)\n",
            dbname_len, dbname, dbname_len);
  }
EOF

#known_dbs="CCMA ECMA ECMASCR PREODB"
known_dbs=""

newarg="$known_dbs "
for arg in $(eval echo $*)
do
  db=$(basename $arg | perl -pe 's/\s+//g; s/\..*$//; s/[_-]//g; tr/a-z/A-Z/')
  newarg="$newarg$db "
done

# Ensure uniqueness (strictly speaking not a requirement, but cleaner)
#newarg=$(echo "$newarg" | perl -pe 's/(\S+)\s*/$1\n/g' | sort -u)

# Lets rock'n'roll now ...
for db in $(eval echo $newarg)
do
  echo "  Static_Init($db);" >> $odbglue
done

cat >> $odbglue << 'EOF'
}
EOF

#ls -l $odbglue

export ODB_CC=${ODB_CC:=""}

rc=0
if [[ "$ODB_CC" != "" ]] ; then
  echo "$ODB_CC -c $odbglue" >&2
        $ODB_CC -c $odbglue  >&2 || rc=$?
fi

exit $rc
