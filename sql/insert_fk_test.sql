INSERT INTO houses VALUES 
  (1, 150000, tstzrange('2015-01-01', '2016-01-01')),
  (1, 200000, tstzrange('2016-01-01', '2017-01-01')),
  (2, 300000, tstzrange('2015-01-01', '2016-01-01')),
  (3, 100000, tstzrange('2014-01-01', '2015-01-01')),
  (3, 200000, tstzrange('2015-01-01', null)),
  (4, 200000, tstzrange(null, '2014-01-01'))
;

SELECT create_temporal_foreign_key('room_has_a_house', 'rooms', 'house_id', 'valid_at', 'houses', 'id', 'valid_at');

-- You can insert a NULL fk
INSERT INTO rooms VALUES (1, NULL, tstzrange('2010-01-01', '2011-01-01'));
DELETE FROM rooms;

-- You can insert a finite fk exactly covered by one row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2016-01-01'));
DELETE FROM rooms;

-- You can insert a finite fk more than covered by one row
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2015-06-01'));
DELETE FROM rooms;

-- You can insert a finite fk exactly covered by two rows
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2017-01-01'));
DELETE FROM rooms;

-- You can insert a finite fk more than covered by two rows
INSERT INTO rooms VALUES (1, 1, tstzrange('2015-01-01', '2016-06-01'));
DELETE FROM rooms;

-- You can't insert a finite fk id not covered by any row
INSERT INTO rooms VALUES (1, 7, tstzrange('2015-01-01', '2016-01-01'));

-- You can't insert a finite fk range not covered by any row
INSERT INTO rooms VALUES (1, 1, tstzrange('1999-01-01', '2000-01-01'));

-- You can't insert a finite fk partially covered by one row
INSERT INTO rooms VALUES (1, 1, tstzrange('2014-01-01', '2015-06-01'));

-- You can't insert a finite fk partially covered by two rows
INSERT INTO rooms VALUES (1, 1, tstzrange('2014-01-01', '2016-06-01'));

-- You can insert an infinite fk exactly covered by one row
INSERT INTO rooms VALUES (1, 3, tstzrange('2015-01-01', null));
DELETE FROM rooms;

-- You can insert an infinite fk more than covered by one row
INSERT INTO rooms VALUES (1, 3, tstzrange('2016-01-01', null));
DELETE FROM rooms;

-- You can insert an infinite fk exactly covered by two rows
INSERT INTO rooms VALUES (1, 3, tstzrange('2014-01-01', null));
DELETE FROM rooms;

-- You can insert an infinite fk more than covered by two rows
INSERT INTO rooms VALUES (1, 3, tstzrange('2014-06-01', null));
DELETE FROM rooms;

-- You can't insert an infinite fk id not covered by any row
INSERT INTO rooms VALUES (1, 7, tstzrange('2015-01-01', null));

-- You can't insert an infinite fk range not covered by any row
INSERT INTO rooms VALUES (1, 1, tstzrange('2020-01-01', null));

-- You can't insert an infinite fk partially covered by one row
INSERT INTO rooms VALUES (1, 4, tstzrange(null, '2020-01-01'));

-- You can't insert an infinite fk partially covered by two rows
INSERT INTO rooms VALUES (1, 3, tstzrange('1990-01-01', null));

DELETE FROM rooms;
DELETE FROM houses;
SELECT drop_temporal_foreign_key('room_has_a_house', 'rooms', 'houses');
