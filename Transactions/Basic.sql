https://github.com/ept/hermitage/blob/master/postgres.md

DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);


select current_setting('transaction_isolation');

SELECT relation::regclass AS relname, * FROM pg_locks;
--G0: Write Cycles (dirty writes)
--Postgres "read committed" prevents Write Cycles (G0) by locking updated rows:
-- aborted in other txn levels

begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 12 where id = 1; -- T2, BLOCKS
update test set value = 21 where id = 2; -- T1
commit; -- T1. This unblocks T2 -- aborts in other txn levels
select * from test; -- T1. Shows 1 => 11, 2 => 21
update test set value = 22 where id = 2; -- T2
commit; -- T2
select * from test; -- either. Shows 1 => 12, 2 => 22

 

-- Dirty reads - uncommitted reads
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 101 where id = 1; -- T1
select * from test; -- T2. Still shows 1 => 10
abort;  -- T1
select * from test; -- T2. Still shows 1 => 10
commit; -- T2

-- no intermediate value is visible
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 101 where id = 1; -- T1
select * from test; -- T2. Still shows 1 => 10
update test set value = 11 where id = 1; -- T1
commit; -- T1
select * from test; -- T2. Now shows 1 => 11
commit; -- T2



-- nothing uncommitted will be visible
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 22 where id = 2; -- T2
select * from test where id = 2; -- T1. Still shows 2 => 20
select * from test where id = 1; -- T2. Still shows 1 => 10
commit; -- T1
commit; -- T2


 
--Postgres "read committed" does not prevent Predicate-Many-Preceders (PMP):
begin; set transaction isolation level read committed; -- T1 
begin; set transaction isolation level read committed; -- T2
select * from test where value = 30; -- T1. Returns nothing
insert into test (id, value) values(3, 30); -- T2
commit; -- T2
select * from test where value % 3 = 0; -- T1. Returns the newly inserted row
commit; -- T1


--Postgres "repeatable read" prevents Predicate-Many-Preceders (PMP):
begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where value = 30; -- T1. Returns nothing
insert into test (id, value) values(3, 30); -- T2
commit; -- T2
select * from test where value % 3 = 0; -- T1. Still returns nothing
commit; -- T1

----

begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2
update test set value = value + 10; -- T1
delete from test where value = 20;  -- T2, BLOCKS
commit; -- T1. This unblocks T2
select * from test where value = 20; -- T2, returns 1 => 20 (despite ostensibly having been deleted)
commit; -- T2


begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
update test set value = value + 10; -- T1
delete from test where value = 20;  -- T2, BLOCKS
commit; -- T1. T2 now prints out "ERROR: could not serialize access due to concurrent update"
abort;  -- T2. There's nothing else we can do, this transaction has failed

------------------------------------------------------------------------
-- Write Skew (G2-item)
-- Postgres "repeatable read" does not prevent Write Skew (G2-item):

begin; set transaction isolation level repeatable read; -- T1
begin; set transaction isolation level repeatable read; -- T2
select * from test where id in (1,2); -- T1
select * from test where id in (1,2); -- T2
update test set value = 11 where id = 1; -- T1
update test set value = 21 where id = 2; -- T2
commit; -- T1
commit; -- T2

-- Postgres "serializable" prevents Write Skew (G2-item):

begin; set transaction isolation level serializable; -- T1
begin; set transaction isolation level serializable; -- T2
select * from test where id in (1,2); -- T1
-- SIREADLOCK page 1
-- SIREADLOCK tuple (0,1)
-- SIREADLOCK tuple (0,2)

select * from test where id in (1,2); -- T2
-- SIREADLOCK page 1
-- SIREADLOCK tuple (0,1)
-- SIREADLOCK tuple (0,2)

update test set value = 11 where id = 1; -- T1
update test set value = 21 where id = 2; -- T2
commit; -- T1
commit; -- T2. Prints out "ERROR: could not serialize access due to read/write dependencies among transactions"


SELECT relation::regclass AS relname, * FROM pg_locks;

-- get virtual txn_id - txn current
SELECT virtualtransaction, txid_current()
FROM pg_locks
WHERE transactionid::text = (txid_current() % (2^32)::bigint)::text;

SELECT locktype, page, tuple, virtualxid, transactionid,
pl.mode, granted, fastpath,  wait_event_type as wtype, wait_event, state, query, waitstart
  FROM pg_locks pl LEFT JOIN pg_stat_activity psa
    ON pl.pid = psa.pid WHERE application_name = 'psql' 
    ORDER BY query;
