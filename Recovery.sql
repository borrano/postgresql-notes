--------------------------------
--https://youtu.be/mD5znxu4Vq4
--https://habr.com/en/company/postgrespro/blog/494246/
-- https://www.interdb.jp/pg/pgsql09.html
--UNDO, REDO records 
--Postgresql only needs redo records - mvcc
-- STEAL - NO STEAL - allow buffers that contains uncommitted transactions to write to disk 
-- FORCE - NO FORCE - dirtied buffers need to be written to disk to commit txn or not
-- modern dbs - STEAL - NO FORCE 
-- to increase sequential disk writes - we need to bulk write dirtied pages.

-- when transaction begins - write begin record to wal
-- when txn commit - write commit record to wal and flush the disk before returning user it committed.
-- first write to wal then buffers
-- What to log? Physical vs logical logging? Non deterministic queries - 
-- Hybrid logging: record changes in page level.

-- LOG sequence numbers: Every log has a sequence number

BEGIN;
DROP TABLE IF EXISTS unary;
CREATE TABLE unary (a int); 
INSERT INTO unary(a)
  SELECT i
  FROM   generate_series(1,100) AS i;
SELECT lsn FROM page_header(get_raw_page('unary', 0)); -- 8/C60EC848 - page_lsn 

SELECT pg_current_wal_flush_lsn(), pg_current_wal_insert_lsn(), pg_current_wal_lsn(); ,
-- flush_lsn - 8/C60E8D50	 - insert_lsn 8/C60EC848 - 8/C60E8D50
COMMIT;
 
SELECT pg_current_wal_flush_lsn(), pg_current_wal_insert_lsn(), pg_current_wal_lsn(); -- 8/C60ECBA0	 8/C60ECBA0	 8/C60ECBA0	

 
-- all wal dirs
-- SELECT * FROM pg_ls_waldir();
-- SELECT pg_current_wal_lsn(), pg_current_wal_insert_lsn(); -- 8/C00D1510	8/C00D1510

CHECKPOINT;
SELECT  pg_switch_wal ();  
UPDATE unary set a = a + 1 WHERE a = 1; -- to avoid full page writes
 
BEGIN;
SELECT txid_current(); -- 3076
SELECT lsn FROM page_header(get_raw_page('unary', 0)); -- 8/C5000EB8
SELECT pg_current_wal_insert_lsn(); -- 8/C5006338
UPDATE unary set a = a + 1 WHERE a = 3;
SELECT pg_current_wal_insert_lsn(); --8/C5006380
SELECT lsn FROM page_header(get_raw_page('unary',0)); -- 8/C5006380
COMMIT;

-- after insert lsn - before insert lsn : size of an update entry
SELECT '8/C5006380'::pg_lsn - '8/C5006338'::pg_lsn;  -- 72 bytes redo log

SELECT file_name, upper(to_hex(file_offset)) file_offset
FROM pg_walfile_name_offset('8/C5006380'); -- filename: 0000000100000008000000C5	offset:6380

sudo /usr/lib/postgresql/14/bin/pg_waldump -p /var/lib/postgresql/14/main/pg_wal     -s 8/C5006338 -e 8/C5006380 0000000100000008000000C5

--rmgr: Heap len (rec/tot): 69/69, tx: 3076, lsn: 8/C5006338, prev 8/C50062C0, desc: HOT_UPDATE off 3 xmax 3076 flags 0x40 ; new off 102 xmax 0, blkref #0: rel 1663/18565/19650 blk 0

Checkpoint 
The point at which the memory and storage to guarantee the persistence by synchronized, called a checkpoint.

Checkpoint occurs in the following cases:

Execution of CHECKPOINT sql statement.
With the interval specified in parameter checkpoint_timeout. By default, it runs at 300 seconds (5 minutes) interval.
Amount of data written to the WAL has reached a parameter max_wal_size. If the WAL data has been written to the amount specified in the parameter (default: 1GB).
At the start of online backup.At the execution of pg_start_backup function.At the execution of pg_basebackup command
At the shutdown of instance. Except for the pg_ctl stop -m immediate command execution
At the time of database configuration. At the execution the CREATE DATABASE / DROP DATABASE statement.

parameters: 
checkpoint_timeout
max_wal_size
log_checkpoints parameter causes checkpoints to be logged. 
checkpoint_completion_target: the default value is 0.5, checkpoint will be completed within 50% of the time until the next checkpoint starts.
 



------------
--- FULL page writes
-- https://www.2ndquadrant.com/en/blog/on-the-impact-of-full-page-writes/
-- the first time we touch a page after checkpoint put full block in the WAL 
-- postgresql uses 8 KB page size 
-- hw and os uses 4KB page size 
-- torn write problem during checkpointing 
-- write amplification

-- ONE of the benefits of HOT updates - i don't have to update indexes and do full page writes
-- Just after a checkpoint, there is a possibility of write
-- I/O to the WAL to spike, because every page that is dirtied is going to get a full page write.

-- you can disable full page writes with full_page_writes parameter
CHECKPOINT;
SELECT  pg_switch_wal ();  

BEGIN;
SELECT pg_current_wal_insert_lsn(); -- 8/C6000028

UPDATE ternary set a = a + 1 WHERE a = 4;
SELECT txid_current();
SELECT pg_current_wal_insert_lsn(); --8/C6001F10

COMMIT;



-- after insert lsn - before insert lsn : size of an update entry
SELECT '8/C6001F10'::pg_lsn - '8/C6000028'::pg_lsn;  -- full page write -- 7912






