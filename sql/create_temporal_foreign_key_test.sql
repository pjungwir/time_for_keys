INSERT INTO houses VALUES 
  (1, 150000, tstzrange('2015-01-01', '2016-01-01')),
  (1, 200000, tstzrange('2016-01-01', '2017-01-01'))
;

-- it works on an empty table
SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');
SELECT drop_temporal_foreign_key('room_has_a_house', 'rooms', 'houses');

-- it works on a table with a NULL foreign key
INSERT INTO rooms VALUES (1, NULL, tstzrange('2015-01-01', '2017-01-01'));
SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');
SELECT drop_temporal_foreign_key('room_has_a_house', 'rooms', 'houses');
DELETE FROM rooms;

-- it works on a table with a FK fulfilled by one row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2016-01-01'));
SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');
SELECT drop_temporal_foreign_key('room_has_a_house', 'rooms', 'houses');
DELETE FROM rooms;

-- it works on a table with a FK fulfilled by two rows
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2016-06-01'));
SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');
SELECT drop_temporal_foreign_key('room_has_a_house', 'rooms', 'houses');
DELETE FROM rooms;

-- it fails on a table with a missing foreign key
INSERT INTO rooms VALUES (1, 2, tstzrange('2015-01-01', '2016-01-01'));
SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');
DELETE FROM rooms;

-- it fails on a table with a completely-uncovered foreign key
INSERT INTO rooms VALUES (1, 1, tstzrange('2010-01-01', '2011-01-01'));
SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');
DELETE FROM rooms;

-- it fails on a table with a partially-covered foreign key
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2018-01-01'));
SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');
DELETE FROM rooms;

DELETE FROM rooms;
DELETE FROM houses;
