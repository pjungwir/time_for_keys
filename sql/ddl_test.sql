-- The parent table is dropped
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
DROP TABLE p;
-- TODO: expect an error
DROP TABLE c;
DROP TABLE p;

-- The parent table is dropped with cascade
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
DROP TABLE p CASCADE;
-- TODO: expect the constraints to be gone
DROP TABLE c;

-- The parent table is renamed
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE p RENAME TO p2;
-- TODO: expect all four constraints to still work
DROP TABLE c;
DROP TABLE p2;

-- The parent id column is dropped
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE p DROP COLUMN id;
-- TODO: expect an error
DROP TABLE c;
DROP TABLE p;

-- The parent id column is dropped with cascade
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE p DROP COLUMN id CASCADE;
-- TODO: expect the constraints to be gone
DROP TABLE c;
DROP TABLE p;

-- The parent valid_at column is dropped
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE p DROP COLUMN valid_at;
-- TODO: expect an error
DROP TABLE c;
DROP TABLE p;

-- The parent valid_at column is dropped with cascade
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE p DROP COLUMN valid_at CASCADE;
-- TODO: expect the constraints to be gone
DROP TABLE c;
DROP TABLE p;

-- The parent id column is renamed
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE p RENAME COLUMN id TO id2;
-- TODO: expect all four constraints to still work
DROP TABLE c;
DROP TABLE p;

-- The parent valid_at column is renamed
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE p RENAME COLUMN valid_at TO valid_at2;
-- TODO: expect all four constraints to still work
DROP TABLE c;
DROP TABLE p;

-- The child table is dropped
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
DROP TABLE c;
-- TODO: expect the constraints to be gone
DROP TABLE p;

-- The child table is renamed
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE c RENAME TO c2;
-- TODO: expect all four constraints to still work
DROP TABLE c2;
DROP TABLE p;

-- The child id column is dropped
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE c DROP COLUMN p_id;
-- TODO: expect the constraints to be gone
DROP TABLE c;
DROP TABLE p;

-- The child valid_at column is dropped
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE c DROP COLUMN valid_at;
-- TODO: expect the constraints to be gone
DROP TABLE c;
DROP TABLE p;

-- The child id column is renamed
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE c RENAME COLUMN p_id TO p_id2;
-- TODO: expect all four constraints to still work
DROP TABLE c;
DROP TABLE p;

-- The child valid_at column is renamed
CREATE TABLE p (id integer, valid_at tstzrange, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
CREATE TABLE c (id integer, valid_at tstzrange, p_id integer, EXCLUDE USING gist (id WITH =, valid_at WITH &&));
SELECT create_temporal_foreign_key('cp', 'c', 'p_id', 'valid_at', 'p', 'id', 'valid_at');
ALTER TABLE c RENAME COLUMN valid_at TO valid_at2;
-- TODO: expect all four constraints to still work
DROP TABLE c;
DROP TABLE p;

