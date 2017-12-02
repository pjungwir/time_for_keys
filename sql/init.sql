CREATE EXTENSION btree_gist;  -- for the GIST exclusion constraints
CREATE EXTENSION time_for_keys;
CREATE TABLE shifts (
  job_id INTEGER,
  worker_id INTEGER,
  valid_at tstzrange,
  EXCLUDE USING gist (worker_id WITH =, valid_at WITH &&)
);
CREATE TABLE houses (
  id INTEGER,
  assessment FLOAT,
  valid_at tstzrange,
  EXCLUDE USING gist (id WITH =, valid_at WITH &&)
);
CREATE TABLE rooms (
  id INTEGER,
  house_id INTEGER,
  valid_at tstzrange,
  EXCLUDE USING gist (id WITH =, valid_at WITH &&)
);
