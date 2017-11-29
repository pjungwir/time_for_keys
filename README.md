pgtemporal
==========

temporal foreign key constraint
-------------------------------

There isn't anything about this built-in, so we need to use triggers to check for it.
Suppose tables `houses` and `rooms` where `rooms` has a `house_id` column that references `houses`.
Whenever `rooms` is inserted or updated,
we need to make sure that the corresponding record(s) from `houses` "cover" the duration of that record from `rooms`.

Also whenever `houses` is updated or deleted, we need to check all the `rooms` that reference that house.

If we have a method to validate one `room` record, we can use that in several of these cases.
This will be [`rooms_house_id_is_covered.sql`].


