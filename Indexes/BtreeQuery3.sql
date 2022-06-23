--------------------
-- In this file - string ops - index only scans

-----------------------------------------------------------------------
-- Demonstrate index-only query evaluation over table "indexed"
-- and its interplay with the table's visibility map.

-- Create a clean slate.
DROP TABLE IF EXISTS indexed;
CREATE TABLE indexed (a int  ,
                      b text,
                      c numeric(3,2));
INSERT INTO indexed(a,b,c)
        SELECT i, md5(i::text), sin(i)
        FROM   generate_series(1,1000000) AS i;


-- ➊ Prepare (a,c) index.  Make sure that all rows on all
--   pages are indeed visible (VACCUM).
CREATE INDEX indexed_a ON indexed USING btree (a);
CREATE INDEX indexed_a_c ON indexed USING btree (a,c);

ANALYZE indexed;
VACUUM indexed;

-- index only scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
SELECT i.c                 
FROM   indexed AS i      
WHERE  i.a < 1 ;   
    
-- seq scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
SELECT i.a                 
FROM   indexed AS i      
WHERE  i.c < 1;    

-- index only scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)                        
SELECT i.a / i.c AS div      
FROM   indexed AS i        
WHERE  i.a < 1 AND i.c <> 0;

-- index only scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)                        
SELECT MAX(i.c) AS m
FROM   indexed AS i
WHERE  i.a < 1;

-- index only scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)                        
SELECT i.a, SUM(i.c) AS s
FROM   indexed AS i
GROUP BY i.a;

-- index scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)                        
SELECT MIN(i.b) AS m
FROM   indexed AS i
WHERE  i.a < 1;

-- ➋ Use extension pg_visibility to check the visibility map
--   (table indexed has 9346 pages)
CREATE EXTENSION IF NOT EXISTS pg_visibility;

SELECT blkno, all_visible
FROM   pg_visibility('indexed')
--
ORDER BY random()   -- pick a few random rows from the visibility map
LIMIT 10;           -- (all entries will have all_visible = true)


SELECT *
FROM   pg_visibility_map_summary('indexed');

-- Heap Fetches: 0
-- all visible no heap fetches neccessary
-- execution time 1.5 ms
-- ➌ Perform sample index-only query
-- 42 index page visited - no heap access
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT SUM(i.c) AS s
  FROM   indexed AS i
  WHERE  i.a < 10000;

set enable_indexonlyscan = off;
-- index scan - 124 buffer access 
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT SUM(i.c) AS s
  FROM   indexed AS i
  WHERE  i.a < 10000;

reset enable_indexonlyscan;


-- ➍ Table updates create old row version that are invisible
--   and may not be produced by an index-only scan
UPDATE indexed AS i
SET    b = '!'
WHERE  i.a % 150 = 0;  -- updates 6666 rows

-- not only 2679 pages all visible
SELECT all_visible
FROM   pg_visibility_map_summary('indexed');


-- this is index only scan 
-- heap fetches 7155 
-- 2.6 ms 
-- Buffers: shared hit=199 dirtied=67

-- This is the index-only query again but it will now touch lots of
-- heap file pages of table "indexed" to check for row visibility... :-/
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT SUM(i.c) AS s
  FROM   indexed AS i
  WHERE  i.a < 10000;


-- ➎ Touch even more rows, requiring even more heap-based visibility checks
--   ⇒ index-only scan becomes unattractive

UPDATE indexed AS i
SET    b = '!'
WHERE  i.a % 10 = 0;  -- updates 100000 rows, EVERY page is affected

SELECT all_visible
FROM   pg_visibility_map_summary('indexed');

-- This is the index-only query again.  The high number of needed row
-- visbility checks make Index Only Scan unattractive, however.
-- index scan is executed - because all pages not visible
EXPLAIN (VERBOSE, ANALYZE)
  SELECT SUM(i.c) AS s
  FROM   indexed AS i
  WHERE  i.a < 10000;


-- ➏ Perform VACUUM to identify invisible rows and mark their
--   space ready for re-use (does not reclaim space and return it
--   to the OS yet), all remaining rows are visible
VACUUM indexed;

SELECT all_visible
FROM   pg_visibility_map_summary('indexed');

-- After VACUMM and index maintentance, a perfect Index Only Scan with
-- no heap fetches for row visbility checks returns. :-)
EXPLAIN (VERBOSE, ANALYZE)
  SELECT SUM(i.c) AS s
  FROM   indexed AS i
  WHERE  i.a < 10000;

DROP   INDEX IF EXISTS indexed_a;
DROP INDEX IF EXISTS indexed_a_c;

----------------------------------------------------------------------
-- INCLUDE 
-- Create a clean slate.

DROP TABLE IF EXISTS indexed;
CREATE TABLE indexed (a int  ,
                      b text,
                      c numeric(3,2));
INSERT INTO indexed(a,b,c)
        SELECT i, md5(i::text), sin(i)
        FROM   generate_series(1,1000000) AS i;


-- ➊ Prepare (a,c) index.  Make sure that all rows on all
--   pages are indeed visible (VACCUM).
CREATE INDEX indexed_ac ON indexed USING btree (a) INCLUDE(c);
 
ANALYZE indexed;
VACUUM indexed;

-- index only scan 
-- even if we are accessed c because we added include index only scan is enough
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
SELECT i.c                 
FROM   indexed AS i      
WHERE  i.a < 1 ;  

-- we can use stored c to scan index - different than composite index
-- Index Cond: (i.a < 1)
--  Filter: (i.c < '2'::numeric)
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
SELECT i.c                 
FROM   indexed AS i      
WHERE  i.a < 1 AND i.c < 2 ;  

DROP INDEX indexed_ac;
CREATE INDEX indexed_ac ON indexed USING btree (a,c)  ;

-- because c is part of index, index condition has c
--   Index Cond: ((i.a < 1) AND (i.c < '2'::numeric))
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
SELECT i.c                 
FROM   indexed AS i      
WHERE  i.a < 1 AND i.c < 2 ;  

-----------------------------------------------------------------------

-- Demonstrate the index-only evaluation of MIN(i.c)/MAX(i.c)
-- and the enforcement of the SQL NULL semantics.

-- ➊ Prepare table and the index, the only index will the composite
--   (c,a) index
CREATE INDEX indexed_c_a ON indexed USING btree (c,a);
ANALYZE indexed;
VACUUM indexed;



-- ➋ Index-only evaluation of MIN(i.c)/MAX(i.c), look out for the
--   Index Only Scan *Backward*

-- MIN MAX ignores NULL values it is added to index cond

-- Index Only Scan using indexed_c_a
-- Index Cond: (i.c IS NOT NULL)
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT MIN(i.c) AS m
  FROM   indexed AS i;

-- Index Only Scan Backward
-- Index Cond: (i.c IS NOT NULL)
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT MAX(i.c) AS m
  FROM   indexed AS i;
 
-----------------------------------------------------------------------

-- INDEX usage with Order By queries
-- Index is already ordered.
-- No need to sort afterwards
--  Demonstrate (non-)support of ORDER BY by Index Scan [Backward]:

-- ➊ supported (also show the value of pipelined "sort")

CREATE INDEX IF NOT EXISTS indexed_c_a ON indexed USING btree (c,a);
ANALYZE indexed;
VACUUM indexed;


ANALYZE indexed;

EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c;

set enable_indexscan = off;

EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c;

reset enable_indexscan;


-- ➋ supported
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c DESC;


-- ➌ supported
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c, i.a;


-- ➍ supported
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c DESC, i.a DESC;


-- ➎ not supported
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c ASC, i.a DESC;  -- 🠴 does not match row visit order in scan
-- create index on specified order
BEGIN;
CREATE INDEX indexed_c_a2 ON indexed USING btree (c,a DESC);
ANALYZE indexed;
-- ➎.5 supported
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c ASC, i.a DESC;  -- match row visit order in scan
ABORT;

-- ➏ supported (also shows how Limit cuts off the Index Scan early → Volcano-style pipelining)
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c
  LIMIT 42;


-- ➐ not supported
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.a;BEGIN;
CREATE INDEX indexed_c_a2 ON indexed USING btree (c,a DESC);
ANALYZE indexed;
-- ➎.5 supported
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c ASC, i.a DESC;  -- match row visit order in scan
ABORT;
onable...
set enable_bitmapscan = off;  -- 🠴 force the system into using Index Scan (to produce rows in a-sorted order)

-- ... now indeed uses Index Scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  WHERE  i.c = 0.0
  ORDER BY i.a;

reset enable_bitmapscan;

set enable_bitmapscan = off;  -- 🠴 force the system into using Index Scan (to produce rows in a-sorted order)

-- ... now indeed uses Index Scan
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  WHERE  i.c = 0.0
  ORDER BY i.a  
  LIMIT 2500;

reset enable_bitmapscan;

-- NULL ordering 

-- sequential scan because null ordering does not match with index
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c NULLS FIRST;


BEGIN;
CREATE INDEX indexed_c_nulls_first on indexed USING btree(c NULLS FIRST);
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c NULLS FIRST;
ABORT;