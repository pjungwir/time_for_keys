/**
 * completely_covers.c -
 * Provides an aggregate function
 * that tells whether a bunch of input ranges competely cover a target range.
 */

#include <errno.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/uio.h>
#include <unistd.h>
#include <string.h>
#include <time.h>

#include <postgres.h>
#include <fmgr.h>
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


PG_MODULE_MAGIC;


#include "completely_covers.h"

typedef struct completely_covers_state {
  TimestampTz covered_to;
  TimestampTz target_start;
  TimestampTz target_end;
  bool target_start_unbounded;
  bool target_end_unbounded;
  bool answer_is_null;
  bool finished;    // Used to avoid further processing if we have already succeeded/failed.
  bool completely_covered;
} completely_covers_state;


Datum completely_covers_transfn(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(completely_covers_transfn);

Datum completely_covers_transfn(PG_FUNCTION_ARGS)
{
  MemoryContext aggContext;
  completely_covers_state *state;
  RangeType *current_range,
            *target_range;
  RangeBound current_start, current_end, target_start, target_end;
  TypeCacheEntry *typcache;
  bool current_empty, target_empty;
  bool first_time;

  if (!AggCheckCallContext(fcinfo, &aggContext)) {
    elog(ERROR, "completely_covers called in non-aggregate context");
  }

  if (PG_ARGISNULL(0)) {
    // Need to use MemoryContextAlloc with aggContext, not just palloc0,
    // or the state will get cleared in between invocations:
    state = (completely_covers_state *)MemoryContextAlloc(aggContext, sizeof(completely_covers_state));
    state->finished = false;
    state->completely_covered = false;
    first_time = true;

    // Need to find out the target range:

    // TODO: Technically this will fail to detect an inconsistent target
    // if only the first row is NULL:
    if (PG_ARGISNULL(2)) {
      // return NULL from the whole thing
      state->answer_is_null = true;
      state->finished = true;
      PG_RETURN_POINTER(state);
    }
    state->answer_is_null = false;

    target_range = PG_GETARG_RANGE(2);
    typcache = range_get_typcache(fcinfo, RangeTypeGetOid(target_range));
    range_deserialize(typcache, target_range, &target_start, &target_end, &target_empty);

    state->target_start_unbounded = target_start.infinite;
    state->target_end_unbounded = target_end.infinite;
    state->target_start = DatumGetTimestampTz(target_start.val);
    state->target_end = DatumGetTimestampTz(target_end.val);
    // ereport(NOTICE, (errmsg("STARTING: state is [%ld, %ld)   target is [%ld, %ld)", state->target_start, state->target_end, DatumGetTimestampTz(target_start.val), DatumGetTimestampTz(target_end.val))));

    state->covered_to = 0;

  } else {
    // ereport(NOTICE, (errmsg("looking up state....")));
    state = (completely_covers_state *)PG_GETARG_POINTER(0);

    // TODO: Is there any better way to exit an aggregation early?
    // Even https://pgxn.org/dist/first_last_agg/ hits all the input rows:
    if (state->finished) PG_RETURN_POINTER(state);

    first_time = false;

    // Make sure the second arg is always the same:
    if (PG_ARGISNULL(2)) {
      ereport(ERROR, (errmsg("completely_covers second argument must be constant across the group")));
    }
    target_range = PG_GETARG_RANGE(2);
    typcache = range_get_typcache(fcinfo, RangeTypeGetOid(target_range));
    range_deserialize(typcache, target_range, &target_start, &target_end, &target_empty);

    // ereport(NOTICE, (errmsg("state is [%ld, %ld)   target is [%ld, %ld)", state->target_start, state->target_end, DatumGetTimestampTz(target_start.val), DatumGetTimestampTz(target_end.val))));
    if (DatumGetTimestampTz(target_start.val) != state->target_start || DatumGetTimestampTz(target_end.val) != state->target_end) {
      ereport(ERROR, (errmsg("completely_covers second argument must be constant across the group")));
    }
  }

  if (PG_ARGISNULL(1)) PG_RETURN_POINTER(state);
  current_range = PG_GETARG_RANGE(1);
  typcache = range_get_typcache(fcinfo, RangeTypeGetOid(current_range));
  range_deserialize(typcache, current_range, &current_start, &current_end, &current_empty);

  // ereport(NOTICE, (errmsg("current is [%ld, %ld)", DatumGetTimestampTz(current_start.val), DatumGetTimestampTz(current_end.val))));

  if (first_time) {
    if (state->target_start_unbounded && !current_start.infinite) {
      state->finished = true;
      state->completely_covered = false;
      PG_RETURN_POINTER(state);
    }
    if (DatumGetTimestampTz(current_start.val) > state->target_start) {
      state->finished = true;
      state->completely_covered = false;
      PG_RETURN_POINTER(state);
    }

  } else {
    // If there is a gap then fail:
    if (DatumGetTimestampTz(current_start.val) > state->covered_to) {
      // ereport(NOTICE, (errmsg("found a gap")));
      state->finished = true;
      state->completely_covered = false;
      PG_RETURN_POINTER(state);
    }
  }

  // This check is why we set covered_to to 0 above on the first pass:
  // Note this check will not check unsorted inputs in some cases:
  //   - the inputs cover the target before we hit an out-of-order input.
  if (DatumGetTimestampTz(current_start.val) < state->covered_to) {
    // Right? Maybe this should be a warning....
    ereport(ERROR, (errmsg("completely_covered first argument should be sorted")));
    // ereport(ERROR, (errmsg("completely_covered first argument should be sorted but got %ld after covering up to %ld", DatumGetTimestampTz(current_start.val), state->covered_to)));
  }

  if (current_end.infinite) {
    state->completely_covered = true;
    state->finished = true;

  } else {
    state->covered_to = DatumGetTimestampTz(current_end.val);

    if (!state->target_end_unbounded && state->covered_to >= state->target_end) {
      state->completely_covered = true;
      state->finished = true;
    }
  }

  PG_RETURN_POINTER(state);
}

Datum completely_covers_finalfn(PG_FUNCTION_ARGS);
PG_FUNCTION_INFO_V1(completely_covers_finalfn);

Datum completely_covers_finalfn(PG_FUNCTION_ARGS)
{
  completely_covers_state *state;

  if (PG_ARGISNULL(0)) PG_RETURN_NULL();

  state = (completely_covers_state *)PG_GETARG_POINTER(0);
  if (state->answer_is_null) {
    PG_RETURN_NULL();
  } else {
    PG_RETURN_BOOL(state->completely_covered);
  }
}
