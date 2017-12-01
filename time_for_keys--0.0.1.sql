/* time_for_keys--0.0.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION time_for_keys" to load this file. \quit



-- TODO: Make this generic for any range type?:
CREATE OR REPLACE FUNCTION
completely_covers_transfn(internal, tstzrange, tstzrange)
RETURNS internal
AS 'time_for_keys', 'completely_covers_transfn'
LANGUAGE c;

CREATE OR REPLACE FUNCTION
completely_covers_finalfn(internal, tstzrange, tstzrange)
RETURNS boolean
AS 'time_for_keys', 'completely_covers_finalfn'
LANGUAGE c;

CREATE AGGREGATE completely_covers(tstzrange, tstzrange) (
  sfunc = completely_covers_transfn,
  stype = internal,
  finalfunc = completely_covers_finalfn,
  finalfunc_extra
);
