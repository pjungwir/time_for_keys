INSERT INTO houses VALUES 
  (1, 150000, tstzrange('2015-01-01', '2016-01-01')),
  (1, 200000, tstzrange('2016-01-01', '2017-01-01')),
  (2, 300000, tstzrange('2015-01-01', '2016-01-01')),
  (3, 100000, tstzrange('2014-01-01', '2015-01-01')),
  (3, 200000, tstzrange('2015-01-01', null)),
  (4, 200000, tstzrange(null, '2014-01-01'))
;

SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');

-- You can update an fk id to NULL
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-06-01'));
UPDATE rooms SET house_id = NULL;
DELETE FROM rooms;

-- You can update the range when the fk is NULL
INSERT INTO rooms VALUES (1, NULL, tstzrange('2015-01-01', '2015-06-01'));
UPDATE rooms SET valid_at = tstzrange('1999-01-01', '2000-01-01');
DELETE FROM rooms;

-- You can update a finite fk exactly covered by one row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2015-01-01', '2016-01-01');
DELETE FROM rooms;

-- You can update a finite fk more than covered by one row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2015-01-01', '2015-06-01');
DELETE FROM rooms;

-- You can update a finite fk exactly covered by two rows
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2015-01-01', '2017-01-01');
DELETE FROM rooms;

-- You can update a finite fk more than covered by two rows
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2015-01-01', '2016-06-01');
DELETE FROM rooms;

-- You can't update a finite fk id not covered by any row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET house_id = 7;
DELETE FROM rooms;

-- You can't update a finite fk range not covered by any row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('1999-01-01', '2000-01-01');
DELETE FROM rooms;

-- You can't update a finite fk partially covered by one row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2014-01-01', '2015-06-01');
DELETE FROM rooms;

-- You can't update a finite fk partially covered by two rows
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2014-01-01', '2016-06-01');
DELETE FROM rooms;

-- You can update an infinite fk exactly covered by one row
INSERT INTO rooms VALUES (1, 3, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2015-01-01', null);
DELETE FROM rooms;

-- You can update an infinite fk more than covered by one row
INSERT INTO rooms VALUES (1, 3, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2016-01-01', null);
DELETE FROM rooms;

-- You can update an infinite fk exactly covered by two rows
INSERT INTO rooms VALUES (1, 3, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2014-01-01', null);
DELETE FROM rooms;

-- You can update an infinite fk more than covered by two rows
INSERT INTO rooms VALUES (1, 3, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2014-06-01', null);
DELETE FROM rooms;

-- You can't update an infinite fk id not covered by any row
INSERT INTO rooms VALUES (1, 3, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET house_id = 7;
DELETE FROM rooms;

-- You can't update an infinite fk range not covered by any row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('2020-01-01', null);
DELETE FROM rooms;

-- You can't update an infinite fk partially covered by one row
INSERT INTO rooms VALUES (1, 4, tstzrange(null, '2012-01-01'));
UPDATE rooms SET valid_at = tstzrange(null, '2020-01-01');
DELETE FROM rooms;

-- You can't update an infinite fk partially covered by two rows
INSERT INTO rooms VALUES (1, 3, tstzrange('2015-01-01', '2015-02-01'));
UPDATE rooms SET valid_at = tstzrange('1990-01-01', null);
DELETE FROM rooms;

DELETE FROM rooms;
DELETE FROM houses;
SELECT drop_temporal_foreign_key('room_has_a_house', 'rooms', 'houses');
