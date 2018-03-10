CREATE OR REPLACE FUNCTION okay_to_delete_house(house_id INTEGER, valid_at tsrange) RETURNS boolean
AS
$$
BEGIN
  -- for each (table, col) with a reference to this house:
  --   if its own valid_at overlaps with our valid_at,
  --   then return false
  --
  -- so we need an information catalog to hold all these temporal foreign keys...
  RETURN true;
END
$$
;
