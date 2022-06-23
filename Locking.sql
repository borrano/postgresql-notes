-- explicit locking

-- row locks - table locks
-- https://www.postgresql.org/docs/current/explicit-locking.html

SELECT * FROM pg_locks pl LEFT JOIN pg_stat_activity psa
    ON pl.pid = psa.pid;

SELECT * FROM pg_locks;



https://github.com/ept/hermitage/blob/master/postgres.md

create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);


select current_setting('transaction_isolation');

-- each transaction acquires virtualxid at the beginning of a transaction
SELECT relation::regclass AS relname, * FROM pg_locks;
--G0: Write Cycles (dirty writes)
--Postgres "read committed" prevents Write Cycles (G0) by locking updated rows:
begin; set transaction isolation level read committed; -- T1
begin; set transaction isolation level read committed; -- T2

update test set value = 11 where id = 1; -- T1
-- acquired locks 
-- RowExclusiveLock test_pkey
-- RowExclusiveLock test
-- ExclusiveLock transactionid
update test set value = 12 where id = 1; -- T2, BLOCKS

update test set value = 21 where id = 2; -- T1
commit; -- T1. This unblocks T2
select * from test; -- T1. Shows 1 => 11, 2 => 21
update test set value = 22 where id = 2; -- T2
commit; -- T2
select * from test; -- either. Shows 1 => 12, 2 => 22


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
