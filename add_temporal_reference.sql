
SELECT  completely_covers(valid_at, $2)
FROM ONLY fk_rel AS x
WHERE pkatt = $1
FOR KEY SHARE OF x




CREATE OR REPLACE FUNCTION add_temporal_reference(reference_name VARCHAR(255), from_table VARCHAR(255), from_column VARCHAR(255), to_table VARCHAR(255), to_column VARCHAR(255) RETURNS void
AS
$$
BEGIN
  -- Define functions to validate this relationship,
  -- and call them.

  EXECUTE FORMAT($f$
    CREATE OR REPLACE FUNCTION temporal_%1$s_in_%2$s_is_covered(child_eid) RETURNS boolean
    AS
    $f2$
    BEGIN
      -- TODO: Why even include ch at all?:
      SELECT  completely_covers(p.valid_at, ch.valid_at)
      FROM    "%1$s" AS ch
      LEFT OUTER JOIN "%3$s" AS p
      ON      ch."%2$s" = p."%4$s"
      WHERE   ch.eid = %5$d
      GROUP BY ch."%2$s"
    END;
    $f2$
    $f$, from_table, from_column, to_table, to_column, child_eid);


    -- From Snodgrass p. 128:
    CREATE OR REPLACE FUNCTION temporal_%1$s_in_%2$s_is_covered(child_eid) RETURNS boolean
    AS
    $f2$
    BEGIN
      SELECT NOT EXISTS (
        SELECT  1
        FROM    %1$s AS ch
        WHERE   ch.eid = %5$d
        AND (
          -- If any of these are true we will fail:
          -- There was no p when ch began:
          NOT EXISTS (
            SELECT  1
            FROM    %3$s AS p
            WHERE   ch.%2$s = p.%4$s
            AND     p.valid_at @> upper(ch.valid_at)
          )
          -- There was no p when ch ended:
          OR NOT EXISTS (
            SELECT  1
            FROM    %3$s AS p
            WHERE   ch.%2$s = p.%4$s
            AND     



    END;
    $f2$
    $f$, from_table, from_column, to_table, to_column, child_eid);

  EXECUTE(FORMAT($f$
    -- TODO: Any problems with function name length here?:
    CREATE OR REPLACE FUNCTION temporal_all_$1_in_$2_are_covered() RETURN boolean
    AS
    $f2$
    BEGIN
      -- TODO: Able to do this all in one SQL statement?:
      FOR parent_id, child_valid_at IN EXECUTE FORMAT($q$ SELECT $1, valid_at FROM $2 $q$, from_column, from_table) LOOP
        IF NOT temporal_$1_is_covered() THEN
          RETURN false;
        END IF;
      END LOOP;
      RETURN true;
    END;
    $f2$
    $f$, from_table, from_column);

  EXECUTE FORMAT('SELECT temporal_all_$1_in_$2_are_covered', from_table, from_column);

  INSERT INTO temporal_references
  (reference_name, from_table, from_column to_table, to_column)
  VALUES
  (reference_name, from_table, from_column, to_table, to_column)
  ;

  EXECUTE FORMAT('
END;
$$
;
