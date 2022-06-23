--------------------
--- In this file: INDEX SCAN VS BITMAP - selectivity correlation

DROP TABLE IF EXISTS ternary CASCADE;

CREATE TABLE ternary (a int NOT NULL, b text NOT NULL, c numeric(3,2));

INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b, sin(i) AS c
FROM generate_series(1, 1000000, 1) AS i;

CREATE INDEX ternary_a ON ternary USING btree(a);
CLUSTER ternary USING ternary_a;

ANALYZE;

select attname, correlation from pg_stats where tablename = 'ternary';

------------------------
-- Selectivy changes query plan

-- Index scan 15 buffer
EXPLAIN (ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.a < 1000;

-- Index scan 6042 buffer
EXPLAIN (ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.a < 500000;

-- Seq scan -- Execution Time: 77.151 ms - buffer=9346  
EXPLAIN (ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.a < 700000;

-- Forcing PostgreSQL to use an index scan: there is indeed no benefit
-- for an Index Scan that accesses too many heap file pages:

set enable_seqscan = off;

-- Execution Time: 89.026 ms Buffers: buffer=8458
EXPLAIN (ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.a < 700000;
 
---------------------------
---- Bitmap Index scan / bitmap heap scan
---- random heap access / sequential heap access 
---- is it clustered or not
---- Create 
CREATE INDEX ternary_b ON ternary USING btree (b text_pattern_ops);
CREATE INDEX ternary_c ON ternary USING btree (c);
--   Buffers: shared hit=2976
--   Bitmap Heap Scan  Heap Blocks: exact=2964
--   2976 - 2964 = 12
EXPLAIN (BUFFERS, ANALYZE)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.c = 0.42;

-- No Index Scan but Bitmap Index Scan + Bitmap Heap Scan?  What is going here?
DROP FUNCTION IF EXISTS page_of(tid);
CREATE FUNCTION page_of(rid tid) RETURNS bigint AS
$$
  SELECT (rid::text::point)[0]::bigint;
$$
LANGUAGE SQL;

-- pages: 33, span: 33 
SELECT COUNT (DISTINCT page_of(i.ctid)) AS pages,
       MAX(page_of(i.ctid)) - MIN(page_of(i.ctid)) + 1 AS span
FROM   ternary AS i
WHERE  i.a < 3532;

-- pages: 2964, span: 9345
SELECT COUNT (DISTINCT page_of(i.ctid)) AS pages,
       MAX(page_of(i.ctid)) - MIN(page_of(i.ctid)) + 1 AS span
FROM   ternary AS i
WHERE  i.c = 0.42;

SELECT Count(*) FROM ternary WHERE c = 0.42;
----------------------------------------------
---- exact vs lossy bitmaps 

show work_mem; -- 4 Mb

--   Heap Blocks: exact=2964
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.c = 0.42  ;
-- Execution Time: 4.189 ms
-- Repeat query with severely restriced working memory
-- (enforce Bitmap Heap Scan):
set work_mem = '64kB';
set enable_indexscan = off;
SET max_parallel_workers_per_gather = 0;
-- Heap Blocks: exact=459 lossy=1149
-- Execution Time: 21.133 ms
-- Heap Blocks: exact=880 lossy=2084

EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.c = 0.42  ;

-- Back to normal configuration
reset work_mem;
reset enable_indexscan;
reset max_parallel_workers_per_gather;

----------------------------------
-- clustering

-- it rewrites the whole table
CLUSTER VERBOSE ternary USING ternary_c;

-- Physical order of rows in heap file now coincides with order in column 'c'
-- ctids (0,1) (0, 2) ..
SELECT i.ctid, i.*
FROM   ternary AS i
ORDER BY i.c -- DESC
LIMIT 10;

-- Repeat query (Bitmap Index Scan will now touch less blocks)
-- heap blocks 34
-- because we did not analyzed the table it still uses bitmap index scan
EXPLAIN (VERBOSE, ANALYZE, Buffers)
  SELECT i.a, i.b
  FROM   ternary AS i
  WHERE  i.c = 0.42;

-- Run ANALYZE on table 'indexed', DBMS updates statistics on
-- row order, now chooses Index Scan over Bitmap Index Scan
ANALYZE ternary;

-- now it uses index scan
-- shared buffers 46
EXPLAIN (VERBOSE, ANALYZE, Buffers)
 SELECT i.a, i.b
 FROM   ternary AS i
 WHERE  i.c = 0.42;

 