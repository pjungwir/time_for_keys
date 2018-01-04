/**
 * time_for_keys.c -
 * Installs a hook so we can get called with a table/column is dropped/renamed,
 * so that we can drop/update our constraints as necessary.
 */

#include <postgres.h>
#include <fmgr.h>
#include <catalog/dependency.h>
#include <catalog/objectaccess.h>
#include <catalog/pg_class.h>

/*
#include <pg_config.h>
#include <miscadmin.h>
#include <utils/array.h>
#include <utils/guc.h>
#include <utils/acl.h>
#include <utils/lsyscache.h>
#include <utils/builtins.h>
#include <utils/rangetypes.h>
#include <utils/timestamp.h>
#include <catalog/pg_type.h>
#include <catalog/catalog.h>
#include <catalog/pg_tablespace.h>
#include <commands/tablespace.h>
*/


PG_MODULE_MAGIC;

void _PG_init(void);
void _PG_fini(void);

void _PG_init(void) {
}

void _PG_fini(void) {
}

