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



-- TODO: Use a more "private" prefix for all our helper functions:

-- These functions are named like the built-in foreign key functions,
-- which you can see in psql by saying `\dftS`.
-- TRI = Temporal Referential Integrity.
-- TODO: Instead of plpgsql we could implement these all as internal C functions,
-- like built-in foreign keys.
-- Then we could cache their query plans and cache the table/column details for each one.
-- Also we could present them better in `\d foo` output.
-- But using the normal `CREATE CONSTRAINT TRIGGER` approach
-- seems a lot easier for our initial feedback-wanted version:

-- TODO: TRI_FKey_cascade_del
CREATE OR REPLACE FUNCTION TRI_FKey_cascade_del()
RETURNS trigger
AS
$$
DECLARE
  from_table TEXT;
  fk_column TEXT;
  from_range_column TEXT;
  to_table TEXT;
  pk_column TEXT;
  to_range_column TEXT;
  -- TODO: Support other types!
  -- This is really tricky because we have to get the value from OLD.${fk_column}.
  old_pk_val INTEGER;
  old_pk_range tstzrange;
BEGIN
  IF NOT TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'TRI_FKey_cascade_del must be called from a DELETE';
  END IF;

  from_table        := quote_ident(TG_ARGV[0]);
  fk_column         := quote_ident(TG_ARGV[1]);
  from_range_column := quote_ident(TG_ARGV[2]);
  to_table          := quote_ident(TG_ARGV[3]);
  pk_column         := quote_ident(TG_ARGV[4]);
  to_range_column   := quote_ident(TG_ARGV[5]);

  EXECUTE format('SELECT ($1:%1$s)::text, $1.%2$s', pk_column, to_range_column)
    USING OLD INTO old_pk_val, old_pk_range;

  -- TODO: This belongs in check_upd instead:
  -- EXECUTE format('SELECT ($1:%1$s)::text, $1.%2$s, ($2:%1$s)::text, $2.%2$s', 
                 -- fk_column, from_range_column)
  -- USING OLD, NEW INTO old_fk_val, old_from_range, new_fk_val, new_from_range;

  -- The FK didn't change so no need to check anything:
  -- IF old_fk_val = new_fk_val AND old_from_range = new_from_range THEN RETURN NEW; END IF;

  -- No FK:
  -- IF new_fk_val IS NULL THEN RETURN NEW; END IF;

  EXECUTE format($q$
    DELETE FROM %1$s
    WHERE   %2$s = $1
    AND     %3$s <@ $2
    $q$, from_table, fk_column, to_table, pk_column)
    USING old_pk_val, old_pk_range;

  -- TODO: Might need to split into two rows:
  EXECUTE format($q$
    UPDATE  %1$s
    -- TODO: .....
    $q$, from_table, fk_column, to_table, pk_column)
    USING old_pk_val, old_pk_range;
END;
$$
LANGUAGE plpgsql;

-- TODO: TRI_FKey_cascade_upd

-- Check Temporal Foreign Key existence (combined for INSERT AND UPDATE).
CREATE OR REPLACE FUNCTION
TRI_FKey_check(
  from_table TEXT, fk_column TEXT, from_range_column TEXT,
  to_table TEXT,   pk_column TEXT, to_range_column TEXT,
  fk_val INTEGER, from_range tstzrange)
RETURNS BOOLEAN
AS
$$
DECLARE
  okay BOOLEAN;
BEGIN
  -- If the FK column is NULL then there is nothing to check:
  IF fk_val IS NULL THEN RETURN true; END IF;

  EXECUTE format($q$
    SELECT  completely_covers(%1$s.%3$s, $2 ORDER BY %1$s.%3$s)
    FROM    %1$s
    WHERE   %1$s.%2$s = $1
    $q$,
    to_table, pk_column, to_range_column) USING fk_val, from_range INTO okay;

  IF okay THEN
    RETURN true;
  ELSE
    -- false or null both imply this:
    RAISE EXCEPTION 'Tried to insert % to %.% but couldn''t find it in %.% for all of [%, %)',
      fk_val::text, from_table, fk_column,
      to_table, pk_column, lower(from_range)::text, upper(from_range)::text
      USING ERRCODE = 23503;
  END IF;
END;
$$
LANGUAGE plpgsql;


-- Checks the FK when a new row is added to the child table:
CREATE OR REPLACE FUNCTION
TRI_FKey_check_ins()
RETURNS trigger
AS
$$
DECLARE
  from_table TEXT;
  fk_column TEXT;
  from_range_column TEXT;
  to_table TEXT;
  pk_column TEXT;
  to_range_column TEXT;
  fk_val INTEGER;
  from_range tstzrange;
BEGIN
  IF NOT TG_OP = 'INSERT' THEN
    RAISE EXCEPTION 'TRI_FKey_check_ins must be called from an INSERT';
  END IF;

  from_table        := quote_ident(TG_ARGV[0]);
  fk_column         := quote_ident(TG_ARGV[1]);
  from_range_column := quote_ident(TG_ARGV[2]);
  to_table          := quote_ident(TG_ARGV[3]);
  pk_column         := quote_ident(TG_ARGV[4]);
  to_range_column   := quote_ident(TG_ARGV[5]);

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s', fk_column, from_range_column)
    USING NEW INTO fk_val, from_range;
  IF TRI_FKey_check(from_table, fk_column, from_range_column,
                    to_table,   pk_column, to_range_column,
                    fk_val, from_range) THEN
    RETURN NEW;
  ELSE
    -- Should have raised already:
    RAISE EXCEPTION 'Should be unreachable';
  END IF;
END
$$
LANGUAGE plpgsql;



-- Checks the FK when an old row is changed in the child table:
CREATE OR REPLACE FUNCTION
TRI_FKey_check_upd()
RETURNS trigger
AS
$$
DECLARE
  from_table TEXT;
  fk_column TEXT;
  from_range_column TEXT;
  to_table TEXT;
  pk_column TEXT;
  to_range_column TEXT;
  fk_val INTEGER;
  from_range tstzrange;
BEGIN
  IF NOT TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'TRI_FKey_check_upd must be called from an UPDATE';
  END IF;

  from_table        := quote_ident(TG_ARGV[0]);
  fk_column         := quote_ident(TG_ARGV[1]);
  from_range_column := quote_ident(TG_ARGV[2]);
  to_table          := quote_ident(TG_ARGV[3]);
  pk_column         := quote_ident(TG_ARGV[4]);
  to_range_column   := quote_ident(TG_ARGV[5]);

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s', fk_column, from_range_column)
    USING NEW INTO fk_val, from_range;
  IF TRI_FKey_check(from_table, fk_column, from_range_column,
                    to_table,   pk_column, to_range_column,
                    fk_val, from_range) THEN
    RETURN NEW;
  ELSE
    -- Should have raised already:
    RAISE EXCEPTION 'Should be unreachable';
  END IF;
END
$$
LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION TRI_FKey_restrict(
  from_table TEXT, fk_column TEXT, from_range_column TEXT,
  to_table TEXT, pk_column TEXT, to_range_column TEXT,
  old_pk_val INTEGER, old_pk_range tstzrange)
RETURNS BOOLEAN
AS
$$
DECLARE
  tmp_table TEXT;
  okay BOOLEAN;
BEGIN
  IF to_table = 'old_references' THEN
    tmp_table = 'old_references2';
  ELSE
    tmp_table = 'old_references';
  END IF;
  EXECUTE format($q$
    SELECT NOT EXISTS (
      WITH %7$s AS (
        SELECT  %1$s.%2$s fk, %1$s.%3$s valid_at
        FROM    ONLY %1$s
        WHERE   %1$s.%2$s = $1
        AND     %1$s.%3$s && $2
      )
      SELECT  1
      FROM    %7$s
      LEFT OUTER JOIN ONLY %4$s
      ON      %4$s.%5$s = %7$s.fk
      GROUP BY %7$s.fk, %7$s.valid_at
      HAVING NOT COALESCE(completely_covers(%4$s.%6$s, %7$s.valid_at ORDER BY %4$s.%6$s), false)
    )
    $q$, from_table, fk_column, from_range_column, to_table, pk_column, to_range_column, tmp_table)
    USING old_pk_val, old_pk_range
    INTO okay;
  RETURN okay;
END;
$$
LANGUAGE plpgsql;



-- Rejects the DELETE if any FKs stil reference the old row:
-- (This is identical to TRI_FKey_restrict_del.)
CREATE OR REPLACE FUNCTION TRI_FKey_noaction_del()
RETURNS trigger
AS
$$
DECLARE
  from_table TEXT;
  fk_column TEXT;
  from_range_column TEXT;
  to_table TEXT;
  pk_column TEXT;
  to_range_column TEXT;
  old_pk_val INTEGER;
  old_pk_range tstzrange;
  okay BOOLEAN;
BEGIN
  IF NOT TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'TRI_FKey_noaction_del must be called from a DELETE';
  END IF;

  from_table        := quote_ident(TG_ARGV[0]);
  fk_column         := quote_ident(TG_ARGV[1]);
  from_range_column := quote_ident(TG_ARGV[2]);
  to_table          := quote_ident(TG_ARGV[3]);
  pk_column         := quote_ident(TG_ARGV[4]);
  to_range_column   := quote_ident(TG_ARGV[5]);

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s', pk_column, to_range_column)
    USING OLD INTO old_pk_val, old_pk_range;

  IF TRI_FKey_restrict(from_table, fk_column, from_range_column,
                       to_table, pk_column, to_range_column,
                       old_pk_val, old_pk_range) THEN
    RETURN NULL;
  ELSE
    RAISE EXCEPTION 'Tried to delete % during [%, %) from % but there are overlapping references in %.%',
      old_pk_val, lower(old_pk_range), upper(old_pk_range), to_table, from_table, fk_column
      USING ERRCODE = 23503;
  END IF;
END;
$$
LANGUAGE plpgsql;



-- Rejects the UPDATE if any FKs stil reference the old row:
-- (This is identical to TRI_FKey_restrict_upd.)
CREATE OR REPLACE FUNCTION TRI_FKey_noaction_upd()
RETURNS trigger
AS
$$
DECLARE
  from_table TEXT;
  fk_column TEXT;
  from_range_column TEXT;
  to_table TEXT;
  pk_column TEXT;
  to_range_column TEXT;
  old_pk_val INTEGER;
  new_pk_val INTEGER;
  old_pk_range tstzrange;
  new_pk_range tstzrange;
  tmp_table TEXT;
BEGIN
  IF NOT TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'TRI_FKey_noaction_upd must be called from an UPDATE';
  END IF;

  from_table        := quote_ident(TG_ARGV[0]);
  fk_column         := quote_ident(TG_ARGV[1]);
  from_range_column := quote_ident(TG_ARGV[2]);
  to_table          := quote_ident(TG_ARGV[3]);
  pk_column         := quote_ident(TG_ARGV[4]);
  to_range_column   := quote_ident(TG_ARGV[5]);

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s, ($2.%1$s)::text, $2.%2$s',
                 pk_column, to_range_column)
    USING OLD, NEW INTO old_pk_val, old_pk_range, new_pk_val, new_pk_range;

  -- If the PK+range didn't change then no need to check anything:
  IF old_pk_val = new_pk_val AND old_pk_range = new_pk_range THEN RETURN NEW; END IF;

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s', pk_column, to_range_column)
    USING OLD INTO old_pk_val, old_pk_range;

  IF TRI_FKey_restrict(from_table, fk_column, from_range_column,
                       to_table, pk_column, to_range_column,
                       old_pk_val, old_pk_range) THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Tried to update % during [%, %) from % but there are overlapping references in %.%',
      old_pk_val, lower(old_pk_range), upper(old_pk_range), to_table, from_table, from_column
      USING ERRCODE = 23503;
  END IF;
END;
$$
LANGUAGE plpgsql;



-- Rejects the DELETE if any FKs stil reference the old row:
CREATE OR REPLACE FUNCTION TRI_FKey_restrict_del()
RETURNS trigger
AS
$$
DECLARE
  from_table TEXT;
  fk_column TEXT;
  from_range_column TEXT;
  to_table TEXT;
  pk_column TEXT;
  to_range_column TEXT;
  old_pk_val INTEGER;
  old_pk_range tstzrange;
  okay BOOLEAN;
BEGIN
  IF NOT TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'TRI_FKey_restrict_del must be called from a DELETE';
  END IF;

  from_table        := quote_ident(TG_ARGV[0]);
  fk_column         := quote_ident(TG_ARGV[1]);
  from_range_column := quote_ident(TG_ARGV[2]);
  to_table          := quote_ident(TG_ARGV[3]);
  pk_column         := quote_ident(TG_ARGV[4]);
  to_range_column   := quote_ident(TG_ARGV[5]);

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s', pk_column, to_range_column)
    USING OLD INTO old_pk_val, old_pk_range;

  IF TRI_FKey_restrict(from_table, fk_column, from_range_column,
                       to_table, pk_column, to_range_column,
                       old_pk_val, old_pk_range) THEN
    RETURN NULL;
  ELSE
    RAISE EXCEPTION 'Tried to delete % during [%, %) from % but there are overlapping references in %.%',
      old_pk_val, lower(old_pk_range), upper(old_pk_range), to_table, from_table, fk_column
      USING ERRCODE = 23503;
  END IF;
END;
$$
LANGUAGE plpgsql;



-- Rejects the UPDATE if any FKs stil reference the old row:
CREATE OR REPLACE FUNCTION TRI_FKey_restrict_upd()
RETURNS trigger
AS
$$
DECLARE
  from_table TEXT;
  fk_column TEXT;
  from_range_column TEXT;
  to_table TEXT;
  pk_column TEXT;
  to_range_column TEXT;
  old_pk_val INTEGER;
  new_pk_val INTEGER;
  old_pk_range tstzrange;
  new_pk_range tstzrange;
  tmp_table TEXT;
BEGIN
  IF NOT TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION 'TRI_FKey_restrict_upd must be called from an UPDATE';
  END IF;

  from_table        := quote_ident(TG_ARGV[0]);
  fk_column         := quote_ident(TG_ARGV[1]);
  from_range_column := quote_ident(TG_ARGV[2]);
  to_table          := quote_ident(TG_ARGV[3]);
  pk_column         := quote_ident(TG_ARGV[4]);
  to_range_column   := quote_ident(TG_ARGV[5]);

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s, ($2.%1$s)::text, $2.%2$s',
                 pk_column, to_range_column)
    USING OLD, NEW INTO old_pk_val, old_pk_range, new_pk_val, new_pk_range;

  -- If the PK+range didn't change then no need to check anything:
  IF old_pk_val = new_pk_val AND old_pk_range = new_pk_range THEN RETURN NEW; END IF;

  EXECUTE format('SELECT ($1.%1$s)::text, $1.%2$s', pk_column, to_range_column)
    USING OLD INTO old_pk_val, old_pk_range;

  IF TRI_FKey_restrict(from_table, fk_column, from_range_column,
                       to_table, pk_column, to_range_column,
                       old_pk_val, old_pk_range) THEN
    RETURN NEW;
  ELSE
    RAISE EXCEPTION 'Tried to update % during [%, %) from % but there are overlapping references in %.%',
      old_pk_val, lower(old_pk_range), upper(old_pk_range), to_table, from_table, from_column
      USING ERRCODE = 23503;
  END IF;
END;
$$
LANGUAGE plpgsql;



-- TODO: TRI_FKey_setdefault_del
-- TODO: TRI_FKey_setdefault_upd
-- TODO: TRI_FKey_setnull_del
-- TODO: TRI_FKey_setnull_upd


-- TODO: need a version that takes schema names too:
CREATE OR REPLACE FUNCTION create_temporal_foreign_key(
  constraint_name TEXT,
  from_table TEXT, from_column TEXT, from_range_column TEXT,
  to_table TEXT,   to_column   TEXT, to_range_column TEXT)
RETURNS VOID
AS
$$
DECLARE
  fk_val INTEGER;
  from_range tstzrange;
BEGIN

  -- TODO: Support CASCADE/SET NULL/SET DEFAULT:
  -- TODO: These should be deferrable to support moving a change's time.
  -- TODO: I should probably have some kind of normalize operation....
  -- Using the name like this is not ideal since it means `constraint_name` can't be 63 chars.
  -- The built-in FKs save the user-provided name for the constraint,
  -- and then create internal constraint triggers as a two-step process,
  -- so they get the constraint trigger's oid before saving the name.
  -- Oh well, there is still lots of room.
  -- If we wanted to maintain our own catalog we could make it an oid-enabled table,
  -- and then we could use the single "temporal foreign key constraint" oid
  -- to name these triggers.

  -- Check the PK when it's DELETEd:
  EXECUTE format($q$
    CREATE CONSTRAINT TRIGGER %1$s
    AFTER DELETE ON %2$s
    FOR EACH ROW EXECUTE PROCEDURE TRI_FKey_restrict_del(%3$s, %4$s, %5$s, %6$s, %7$s, %8$s)
    $q$,
    quote_ident(concat('TRI_ConstraintTrigger_a_', constraint_name, '_del')),
    quote_ident(to_table),
    quote_nullable(from_table),
    quote_nullable(from_column),
    quote_nullable(from_range_column),
    quote_nullable(to_table),
    quote_nullable(to_column),
    quote_nullable(to_range_column));

  -- TODO: Support CASCASE/SET NULL/SET DEFAULT:
  -- Check the PK when it's UPDATEd:
  EXECUTE format($q$
    CREATE CONSTRAINT TRIGGER %1$s
    AFTER UPDATE ON %2$s
    FOR EACH ROW EXECUTE PROCEDURE TRI_FKey_restrict_upd(%3$s, %4$s, %5$s, %6$s, %7$s, %8$s)
    $q$,
    quote_ident(concat('TRI_ConstraintTrigger_a_', constraint_name, '_upd')),
    quote_ident(to_table),
    quote_nullable(from_table),
    quote_nullable(from_column),
    quote_nullable(from_range_column),
    quote_nullable(to_table),
    quote_nullable(to_column),
    quote_nullable(to_range_column));

  -- Check the FK when it's INSERTed:
  EXECUTE format($q$
    CREATE CONSTRAINT TRIGGER %1$s
    AFTER INSERT ON %2$s
    FOR EACH ROW EXECUTE PROCEDURE TRI_FKey_check_ins(%3$s, %4$s, %5$s, %6$s, %7$s, %8$s)
    $q$,
    quote_ident(concat('TRI_ConstraintTrigger_c_', constraint_name, '_ins')),
    quote_ident(from_table),
    quote_nullable(from_table),
    quote_nullable(from_column),
    quote_nullable(from_range_column),
    quote_nullable(to_table),
    quote_nullable(to_column),
    quote_nullable(to_range_column));

  -- Check the FK when it's UPDATEd:
  EXECUTE format($q$
    CREATE CONSTRAINT TRIGGER %1$s
    AFTER UPDATE ON %2$s
    FOR EACH ROW EXECUTE PROCEDURE TRI_FKey_check_upd(%3$s, %4$s, %5$s, %6$s, %7$s, %8$s)
    $q$,
    quote_ident(concat('TRI_ConstraintTrigger_c_', constraint_name, '_upd')),
    quote_ident(from_table),
    quote_nullable(from_table),
    quote_nullable(from_column),
    quote_nullable(from_range_column),
    quote_nullable(to_table),
    quote_nullable(to_column),
    quote_nullable(to_range_column));

  -- Validate all the existing rows.
  --   The built-in FK triggers do this one-by-one instead of with a big query,
  --   which seems less efficient, but it does have better code reuse.
  --   I'm following their lead here:
  FOR fk_val, from_range IN EXECUTE format(
    'SELECT %2$s, %3$s FROM %1$s',
    quote_ident(from_table), quote_ident(from_column), quote_ident(from_range_column)
  ) LOOP
    PERFORM TRI_FKey_check(
      from_table, from_column, from_range_column,
      to_table,   to_column,   to_range_column,
      fk_val, from_range);
  END LOOP;

  -- TODO: Keep it in a catalog?
END;
$$
LANGUAGE plpgsql;

-- TODO: install a listener for `alter table` and `drop table` commands.

CREATE OR REPLACE FUNCTION drop_temporal_foreign_key(
  constraint_name TEXT,
  from_table TEXT,
  to_table TEXT
)
RETURNS VOID
AS
$$
DECLARE
BEGIN
  EXECUTE format(
    'DROP TRIGGER %2$s ON %1$s',
    quote_ident(to_table),
    quote_ident(concat('TRI_ConstraintTrigger_a_', constraint_name, '_del')));
  EXECUTE format(
    'DROP TRIGGER %2$s ON %1$s',
    quote_ident(to_table),
    quote_ident(concat('TRI_ConstraintTrigger_a_', constraint_name, '_upd')));
  EXECUTE format(
    'DROP TRIGGER %2$s ON %1$s',
    quote_ident(from_table),
    quote_ident(concat('TRI_ConstraintTrigger_c_', constraint_name, '_ins')));
  EXECUTE format(
    'DROP TRIGGER %2$s ON %1$s',
    quote_ident(from_table),
    quote_ident(concat('TRI_ConstraintTrigger_c_', constraint_name, '_upd')));
END;
$$
LANGUAGE plpgsql;

