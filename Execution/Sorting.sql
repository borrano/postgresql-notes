-----------------------------------------------------------------------
-- Sorting in PostgreSQL


-- Recreate and populate playground table "indexed",
-- rename primary key index to "indexed_a"
DROP TABLE IF EXISTS indexed;
CREATE TABLE indexed (a int PRIMARY KEY,
                      b text,
                      c numeric(3,2));
CREATE INDEX indexed_a ON indexed(a);

INSERT INTO indexed(a,b,c)
        SELECT i, md5(i::text), sin(i)
        FROM   generate_series(1,1000000) AS i;

ANALYZE indexed;
 

-----------------------------------------------------------------------
-- Sort is an ubiquitous plan operator used in ORDER BY, DISTINCT,
-- GROUP BY, (merge) join, window functions, ...

-- Focus is on sorting in this experiment
set enable_hashagg  = off;
set enable_hashjoin = off;
set max_parallel_workers = 0;
set max_parallel_workers_per_gather = 0;
set enable_nestloop = off;

-- Query ➊: ORDER BY

EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c;


-- Query ➋: DISTINCT
-- Sort - Unique
EXPLAIN (VERBOSE, ANALYZE)
  SELECT DISTINCT i.c
  FROM   indexed AS i;


-- Query ➌: GROUP BY
-- Sort - Group Aggregate
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.c, SUM(i.a) AS s
  FROM   indexed AS i
  GROUP BY i.c;


-- Query ➍: merge join
EXPLAIN (VERBOSE, ANALYZE)
  SELECT DISTINCT i1.a
  FROM   indexed AS i1,
         indexed AS i2
  WHERE  i1.a = i2.c :: int;


-- Query ➎ (not on slide): window aggregate

EXPLAIN (VERBOSE, ANALYZE)
 SELECT i.c, SUM(i.a) OVER 
 (ORDER BY i.c ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS w
 FROM   indexed AS i;


-- Using column "a" (instead of "c") as the sorting/grouping/join
-- criterion leads PostgreSQL to use a sorted Index (Only) Scan instead
-- of the Sort plan operator.  For example:

-- Query ➊ (sorting criterion "c" → "a")
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.a;         -- 🠴 i.a instead of i.c

-- Query ➋ ("c" → "a")
-- index only scan
EXPLAIN (VERBOSE, ANALYZE)
  SELECT DISTINCT i.a   -- 🠴 i.a instead of i.c
  FROM   indexed AS i;

-- Query ➌ ("c" → "a")
-- GroupAggregate - index scan
EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.a, SUM(i.c) AS s
  FROM   indexed AS i
  GROUP BY i.a;         -- 🠴 i.a instead of i.c


reset enable_hashagg ;
reset enable_hashjoin;
reset max_parallel_workers;
reset max_parallel_workers_per_gather;
reset enable_nestloop;

-----------------------------------------------------------------------
-- External vs in-memory sort

-- PostgreSQL chooses sort implementations based on
-- memory constraints/availability

set max_parallel_workers = 0;
set max_parallel_workers_per_gather = 0;

-- ➊ Evaluate query under tight memory constraints
show work_mem;
-- Buffers: shared hit=9346, temp read=9336 written=9361
-- Sort Method: external merge  Disk: 50976kB
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c;


-- ➋ Re-valuate query with plenty of RAM-based temporary working memory
set work_mem = '1GB';

EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  ORDER BY i.c;

reset work_mem;
reset max_parallel_workers;
reset max_parallel_workers_per_gather;


