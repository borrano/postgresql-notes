
--https://wiki.postgresql.org/wiki/SSI

DROP TABLE IF EXISTS test;
create table test (id int primary key, value int);
insert into test (id, value) values (1, 10), (2, 20);

VACUUM;

SELECT lp, t_xmin, t_xmax, t_field3, combined_flags, raw_flags  FROM ShowHeap('test', 0);

BEGIN;
INSERT INTO test values(3, 30);
SELECT lp, t_xmin, t_xmax, combined_flags, raw_flags  FROM ShowHeap('test', 0);
SELECT * FROM test;
ABORT;

SELECT lp, t_xmin, t_xmax, combined_flags, raw_flags  FROM ShowHeap('test', 0);

BEGIN;
SELECT txid_current();
DELETE FROM test WHERE id = 1;
SELECT lp, t_xmin, t_xmax, combined_flags, raw_flags  FROM ShowHeap('test', 0); -- HEAP_KEYS_UPDATED
SELECT * FROM test;
ABORT;

SELECT lp, t_xmin, t_xmax, combined_flags, raw_flags  FROM ShowHeap('test', 0);

BEGIN;
SELECT txid_current();
UPDATE test set value = 12 WHERE id = 2;
SELECT lp, (t_xmin, txid_status(t_xmin::BIGINT)), (t_xmax, txid_status(t_xmax::BIGINT)), combined_flags, raw_flags  FROM ShowHeap('test', 0);
SELECT ctid, * FROM test;
ABORT;

SELECT lp, (t_xmin, txid_status(t_xmin::BIGINT)), (t_xmax, txid_status(t_xmax::BIGINT)), combined_flags, raw_flags  FROM ShowHeap('test', 0);

-- When PostgreSQL shuts down or whenever the checkpoint process runs, the data of the clog are written into files stored under the pg_xact subdirectory

SELECT txid_current_snapshot(); -- 4911:4911:
--The textual representation of the txid_current_snapshot is ‘xmin:xmax:xip_list’, and the components are described as follows.
--xmin Earliest txid that is still active. All earlier transactions will either be committed and visible, or rolled back and dead.
--xmax First as-yet-unassigned txid. All txids greater than or equal to this are not yet started as of the time of the snapshot, and thus invisible.
--xip_list Active txids at the time of the snapshot. The list includes only active txids between xmin and xmax. 


--In the READ COMMITTED isolation level, the transaction obtains a snapshot whenever an SQL command is executed; otherwise (REPEATABLE READ or SERIALIZABLE), the transaction only gets a snapshot when the first SQL command is executed. The obtained transaction snapshot 
--is used for a visibility check of tuples, which is described in Section 5.7.