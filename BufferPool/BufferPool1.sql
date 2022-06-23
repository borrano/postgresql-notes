DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int NOT NULL, b text NOT NULL, c float);
INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b, log(i) AS c
FROM generate_series(1, 1000, 1) AS i;

-- heap file locations

SELECT oid, datname FROM pg_database WHERE datname = 'test'; -- database file

SELECT relfilenode, relname FROM pg_class WHERE relname = 'ternary'; -- table file

SELECT relname, s.setting || '/' || pg_relation_filepath(oid) FROM pg_class as c, pg_settings as s
WHERE s.name = 'data_directory' AND c.relkind ='r' AND c.relname = 'ternary';

-- sudo hexdump -C /var/lib/postgresql/14/main/base/18565/19197


-- row identifier (page, row pointer)
SELECT ctid, * FROM ternary LIMIT 10;

-- /usr/lib/postgresql/14/bin/pg_controldata /var/lib/postgresql/14/main/
-- Database block size:                  8192

------------------------------------------
--- buffer cache 

show shared_buffers; -- 128MB
-- Enable a PostgreSQL extension that lets us peek inside the buffer:
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

-- How many pages can the current buffer hold overall?
SELECT Count(*) FROM pg_buffercache  ; -- 16384

SELECT c.*
FROM pg_class AS c
WHERE c.relname = 'ternary';

-- tables that occupy buffer pool cache most.
SELECT c.relname, count(*) AS buffers
FROM pg_class c, pg_buffercache b, pg_database d
WHERE  b.relfilenode=c.relfilenode AND (b.reldatabase=d.oid AND d.datname=current_database())
GROUP BY c.relname
ORDER BY count(*) DESC
LIMIT 10;
 
-- buffer content summary 
SELECT c.relname, pg_size_pretty(count(*) * 8192) as buffered, 
       round(100.0 * count(*) / (SELECT setting FROM pg_settings WHERE name='shared_buffers')::integer,1) AS buffers_percent,
       round(100.0 * count(*) * 8192 / pg_relation_size(c.oid), 1) AS percent_of_relation
FROM pg_class c, pg_buffercache b, pg_database d
WHERE   b.relfilenode = c.relfilenode AND (b.reldatabase = d.oid AND d.datname = current_database())
GROUP BY c.oid,c.relname
ORDER BY 3 DESC
LIMIT 10;


-- 
SELECT c.relname, count(*) AS buffers,usagecount
FROM pg_class c, pg_buffercache b, pg_database d 
WHERE   b.relfilenode = c.relfilenode AND (b.reldatabase = d.oid AND d.datname = current_database())
GROUP BY c.relname,usagecount
ORDER BY c.relname,usagecount;


SELECT b.bufferid, pg_filenode_relation(0, b.relfilenode), 
       b.relblocknumber,  b.isdirty,  b.usagecount, b.pinning_backends
FROM pg_buffercache as b LIMIT 100 ;

-- isdirty
-- usagecount
-- pinning_backends
-- bufferid : buffer slot
-- relblock number

--change shared buffer size.
--sudo gedit /etc/postgresql/14/main/postgresql.conf	
--shared_buffers:512kB
--service postgresql@14-main restart 

show shared_buffers; -- 256kB
SELECT Count(*) FROM pg_buffercache  ;  -- 16 pages

EXPLAIN (BUFFERS, VERBOSE, ANALYZE)
SELECT * FROM ternary WHERE a < 100;

SELECT b.bufferid, b.relfilenode, pg_filenode_relation(0, b.relfilenode), 
       b.relblocknumber,  b.isdirty,  b.usagecount, b.pinning_backends
FROM pg_buffercache as b  
WHERE   b.relfilenode  = 19635;


--sudo gedit /etc/postgresql/14/main/postgresql.conf	
--shared_buffers:128Mb
--service postgresql@14-main restart 

EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
UPDATE ternary
SET c = -1
WHERE a = 11;
-- Buffers: shared hit=3 read=11 dirtied=2

-- 2 pages diried
SELECT b.bufferid, b.relfilenode, pg_filenode_relation(0, b.relfilenode), 
       b.relblocknumber,  b.isdirty,  b.usagecount, b.pinning_backends
FROM pg_buffercache as b  
WHERE   b.relfilenode  = 19289 AND b.isdirty;

CHECKPOINT; -- write dirty pages 
-- no dirty pages after that
SELECT b.bufferid, b.relfilenode, pg_filenode_relation(0, b.relfilenode), 
       b.relblocknumber,  b.isdirty,  b.usagecount, b.pinning_backends
FROM pg_buffercache as b  
WHERE   b.relfilenode  = 19289  ;

-------------------
-- Buffer replacement policies 

-- usage_count - dirty
-- sequential flooding

-- when a query is too big a ring buffer is allocated to it 
-- RING buffer to avoid sequential flooding

-- not swamp 

------------------------------------
--- monitoring buffer pool
--- pg_stat_bgwriter

SELECT buffers_clean, buffers_checkpoint, buffers_backend, buffers_backend_fsync FROM pg_stat_bgwriter;

--buffers_clean: Number of buffers written by the background writer
--buffers_checkpoint: Number of buffers written during checkpoints
--buffers_backend : Number of buffers written directly by a backend. A backend (any process besides the background writer that
-- also handles checkpoints) tried to allocate a buffer, and the one it was given to
-- use was dirty. In that case, the backend must write the dirty block out itself
-- before it can use the buffer page.
--buffers_backend_fsync: Number of times a backend had to execute its own fsync call (normally the background writer handles those even when the backend does its own write)
-----------------------------
--- various concept

-- Double buffering
-- if you read a database block from disk that's not been
-- requested before by the server, it's first going to make its way into the OS cache, and then it
-- will be copied into the database buffer cache, what's referred to as double buffering

-- effective_cache_size parameter: 
-- when making decisions such as whether it is efficient to use an index or not, the database
-- compares sizes it computes against the effective sum of all these caches