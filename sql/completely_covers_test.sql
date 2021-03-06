INSERT INTO shifts VALUES
  (1, 1, tstzrange('2017-11-27 06:00:00', '2017-11-27 12:00:00')),
  (1, 2, tstzrange('2017-11-27 12:00:00', '2017-11-27 17:00:00')),
  (2, 3, tstzrange('2017-11-27 06:00:00', '2017-11-27 12:00:00')),
  (2, 4, tstzrange('2017-11-27 13:00:00', '2017-11-27 17:00:00')),
  (3, 5, tstzrange(null,                  '2017-11-27 12:00:00')),
  (3, 5, tstzrange('2017-11-27 12:00:00', '2017-11-27 17:00:00')),
  (4, 6, tstzrange('2017-11-27 06:00:00', '2017-11-27 12:00:00')),
  (4, 7, tstzrange('2017-11-27 12:00:00', null))
;

-- TRUE:

-- it covers when the range matches one exactly:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 12:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it covers when the range matches two exactly:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it covers when the range has extra in front:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 08:00:00', '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it covers when the range has extra behind:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 14:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it covers when the range has extra on both sides:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 08:00:00', '2017-11-27 14:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- an infinite start will cover a finite target:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 3;

-- an infinite start will cover an infinite target:
SELECT  completely_covers(valid_at, tstzrange(NULL, '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 3;

-- an infinite end will cover a finite target:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 4;

-- an infinite end will cover an infinite target:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', NULL))
FROM    shifts
WHERE   job_id = 4;

-- FALSE:

-- it does not cover when the range is null:
SELECT  completely_covers(NULL, tstzrange('2017-11-27 08:00:00', '2017-11-27 14:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it does not cover when the range misses completely:
SELECT  completely_covers(valid_at, tstzrange('2017-11-29 08:00:00', '2017-11-29 14:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it does not cover when the range has something at the beginning:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 04:00:00', '2017-11-27 14:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it does not cover when the range has something at the end:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 20:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it does not cover when the range has something in the middle:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 2;

-- it does not cover when the range is lower-unbounded:
SELECT  completely_covers(valid_at, tstzrange(NULL, '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 1;

-- it does not cover when the range is upper-unbounded:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', NULL))
FROM    shifts
WHERE   job_id = 1;

-- it does not cover when the range is both-sides-unbounded:
SELECT  completely_covers(valid_at, tstzrange(NULL, NULL))
FROM    shifts
WHERE   job_id = 1;

-- an infinite start will not cover a finite target if there is uncovered time at the end:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 06:00:00', '2017-11-27 20:00:00'))
FROM    shifts
WHERE   job_id = 3;

-- an infinite start will not cover an infinite target if there is uncovered time at the end:
SELECT  completely_covers(valid_at, tstzrange(NULL, '2017-11-27 20:00:00'))
FROM    shifts
WHERE   job_id = 3;

-- an infinite end will not cover a finite target if there is uncovered time at the beginning:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 03:00:00', '2017-11-27 17:00:00'))
FROM    shifts
WHERE   job_id = 4;

-- an infinite end will not cover an infinite target if there is uncovered time at the beginning:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 03:00:00', NULL))
FROM    shifts
WHERE   job_id = 4;


-- NULL:

-- it is unknown when the target is null:
SELECT  completely_covers(valid_at, null)
FROM    shifts
WHERE   job_id = 1;

-- Errors:

-- it fails if the input ranges go backwards:
SELECT  completely_covers(valid_at, tstzrange('2017-11-27 13:00:00', '2017-11-27 20:00:00') ORDER BY worker_id DESC)
FROM    shifts
WHERE   job_id = 1;

-- TODO: handle an empty target range? e.g. [5, 5)
-- Or maybe since that is a self-contradiction maybe ignore that case?

DELETE FROM shifts;
