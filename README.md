time\_for\_keys
===============

This extension lets you define referential integrity constraints (foreign keys)
between temporal tables,
like described in [Snodgrass 127&ndash;130](https://www2.cs.arizona.edu/~rts/publications.html).

We focus on *valid-time* (aka state-time) tables, not transaction-time (aka system-time) tables,
although these keys should work in either case.
In other words our keys are for when you want a history of some *thing*.
If you want a history of the *database*, e.g. for auditing,
Vlad Arkhipov's [temporal tables extension](https://pgxn.org/dist/temporal_tables/)
will automatically preserve that history.
Since it is automatically-generated there is less need for foreign keys.
I haven't yet considered referential integrity on bi-temporal tables,
although if you want that let me know. :-)

The tricky thing about temporal tables is that a thing's identity may live in several rows,
as long as the rows' periods don't overlap.
You can create a "temporal primary key" already
using [exclusion constraints](https://www.postgresql.org/docs/current/static/rangetypes.html#RANGETYPES-CONSTRAINT),
but you still need support for checking foreign keys.
If you have a `houses` table and a `rooms` table,
you probably want a foreign key to ensure that every room's house is really there.
In a temporal table you'd make sure that the house exists
for any point in time that the room references it.
For example if the house was built in 2015,
the room's history can't begin in 2014.
In addition the house may have several records due to changes over time,
and if the room didn't change then its foreign key is not satisfied by any one house record,
but by the "sum" of them.
This can't be expressed by regular foreign keys,
so this extension adds constraints for it.

I wrote a [temporal tables annotated bibliography](https://illuminatedcomputing.com/posts/2017/12/temporal-databases-bibliography/) if you are interested in learning more about them.

For another perspective you could consult [the *Time for Keys* music video](https://www.youtube.com/watch?v=l1FrF2Rl8gc).
These opening lines are pretty much foreign keys in a nutshell, right?:

<i>I have to say</i><br/>
<i>it's a world of us and them</i><br/>
<i>and that when things go wrong</i><br/>
<i>you won't accept the blame.</i><br/>


Installing
----------

This package installs like any Postgres extension. First say:

    make && sudo make install

You will need to have `pg_config` in your path,
but normally that is already the case.
You can check with `which pg_config`.

Then in the database of your choice say:

    CREATE EXTENSION time_for_keys;


Usage
-----

You can create a new temporal foreign key using:

`create_temporal_foreign_key(`*constraint-name*`, `*from-table*`, `*from-column*`, `*from-range-column*`, `*to-table*`, `*to-column*`, `*to-range-column*`)`

For example:

    SELECT create_temporal_foreign_key(
      'rooms_have_a_house',
      'rooms',  'house_id', 'valid_at',
      'houses', 'id',       'valid_at'
    );

Later you can drop the constraint with:

`drop_temporal_foreign_key(`*constraint-name*`, `*from-table*`, `*to-table*`)`

For example:

    SELECT drop_temporal_foreign_key('rooms_have_a_house', 'rooms', 'houses');

Temporal foreign keys are enforced with triggers,
just like regular Postgres foreign keys.
For each temporal foreign key we create four `CONSTRAINT TRIGGER`s that fire on:

  - parent table `DELETE`s
  - parent table `UPDATE`s
  - child table `INSERT`s
  - child table `UPDATE`s


TODO
----

There are lots of ways to extend this work:

- Support non-integer foreign keys.
- Support more range types.
- Support multi-column foreign keys.
- Support `ON DELETE CASCADE` and `ON UPDATE CASCADE`.
- Support `ON DELETE SET NULL` and `ON UPDATE SET NULL`.
- Support `ON DELETE SET DEFAULT` and `ON UPDATE SET DEFAULT`.
- Support `MATCH SIMPLE` and maybe `MATCH PARTIAL` (not applied to `valid_at` though).
- Benchmark against the traditional Snodgrass approach (nested `NOT EXISTS`).
- Save the query plans for our queries, like in `backend/utils/adt/ri_triggers.c`?
- Use `_PG_init` to set up caches like the [`temporal` extension](https://github.com/arkhipov/temporal_tables).?
- The built-in FK code adds collation operators if the columns' collation isn't the same. We probably need to do something like that too.
- Support temporal FKs on views? Probably not....


Author
------

Paul A. Jungwirth

