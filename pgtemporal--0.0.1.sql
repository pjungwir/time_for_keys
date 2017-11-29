/* pgtemporal--0.0.1.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pgtemporal" to load this file. \quit



-- TODO: Make this generic for any range type?:
CREATE OR REPLACE FUNCTION
completely_covers_transfn(internal, tstzrange, tstzrange)
RETURNS internal
AS 'pgtemporal', 'completely_covers_transfn'
LANGUAGE c;

CREATE OR REPLACE FUNCTION
completely_covers_finalfn(internal, tstzrange, tstzrange)
RETURNS boolean
AS 'pgtemporal', 'completely_covers_finalfn'
LANGUAGE c;

CREATE AGGREGATE completely_covers(tstzrange, tstzrange) (
  sfunc = completely_covers_transfn,
  stype = internal,
  finalfunc = completely_covers_finalfn,
  finalfunc_extra
);
