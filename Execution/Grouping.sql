-----------------------------------------------------------------------
-- Execution of group by using hashing
-- Grouping in PostgreSQL

-- Switch from hashing to sorting when work_mem becomes scarce or when
-- the estimated number of groups becomes (too) large.


-- ➊ Prepare table grouped, start off with default work_mem

DROP TABLE IF EXISTS grouped;
CREATE TABLE grouped (a int, g int);

INSERT INTO grouped (a, g)
  SELECT i, i % 10000                      -- 10⁴ groups
  FROM   generate_series(1,1000000) AS i;  -- 10⁶ rows

ANALYZE grouped;
 
set max_parallel_workers = 0;
set max_parallel_workers_per_gather = 0;

show work_mem;

-- ➋ Perform grouping with plenty of work_mem
--  HashAggregate  (cost=70675.00..78587.95 rows=10045 width=12) 
-- (actual time=163.195..218.373 rows=10000 loops=1)
-- Batches: 1  Memory Usage: 1425kB
 EXPLAIN (VERBOSE, ANALYZE)
  SELECT g.g, SUM(g.a) AS s
  FROM   grouped AS g
  GROUP BY g.g;


-- ➌ Repeat grouping with scarce work_mem

set work_mem = '512kB';
-- Planned Partitions: 4  Batches: 5  Memory Usage: 529kB  Disk Usage: 19696kB if parallelism is disable
-- if not external merge sort
EXPLAIN (VERBOSE, ANALYZE)
  SELECT g.g, SUM(g.a) AS s
  FROM   grouped AS g
  GROUP BY g.g;


-- ➍ Group count 𝐺 is conservatively overestimated unless truly obvious for the system
-- group count is overestimated
--  HashAggregate  (cost=73175.00..81112.12 rows=9970 width=12) (actual time=159.752..159.758 rows=2 loops=1)
EXPLAIN (VERBOSE, ANALYZE)
  SELECT g.g % 2, SUM(g.a) AS s
  FROM   grouped AS g
  GROUP BY g.g % 2;     -- 🠴 will create three groups max, goes undetected by PostgreSQL :-(


EXPLAIN (VERBOSE, ANALYZE)
  SELECT g.g % 2 = 0, SUM(g.a) AS s
  FROM   grouped AS g
  GROUP BY g.g % 2 = 0;  -- 🠴 creates a Boolean, this IS detected by PostgreSQL (|dom(bool)| = 2)


reset work_mem;
reset max_parallel_workers;
reset max_parallel_workers_per_gather;


-----------------------------------------------------------------------
-- Parallel grouping and aggregation.
-- Works for distributive aggregate SUM/+, does not work for
-- array_agg/||.


-- ➊ Enable generation of parallel plans
--   (⚠️ this is supposed to be disabled in the lecture)

set max_parallel_workers = default;             -- = 8
set max_parallel_workers_per_gather = default;  -- = 8


-- ➋ Parallel grouping for SUM
-- parallel seq scan - loops: 3
-- 
EXPLAIN (VERBOSE, ANALYZE)
  SELECT g.g, SUM(g.a) AS s       -- 10⁴ groups
  FROM   grouped AS g             -- 10⁶ rows
  GROUP BY g.g;


-- ➌ Check aggregates and their finalize operations (for type int)
--   (aggregates that can be used in parallel/partial mode [missing: array_agg, ...])

SELECT a.aggfnoid, a.aggcombinefn, a.agginitval, t.typname
FROM   pg_aggregate AS a, pg_type AS t
WHERE  a.aggcombinefn <> 0 and a.aggkind = 'n'
AND    a.aggtranstype = t.oid AND t.typname LIKE '%int_';


-- ➍ Plans with non-distributive aggregates cannot be //ized this easily,
--   example: array_agg/||
--
--   array_agg({1,3,5,2,4,6} ORDER BY x)
--    ≠
--   array_agg({1,3,5} ORDER BY x) || array_agg({2,4,6} ORDER BY x)

SELECT array_agg(x ORDER BY x) AS xs
FROM   generate_series(1, 10) AS x;

-- ≠

SELECT (
  (SELECT array_agg(x ORDER BY x) AS xs
   FROM   generate_series(1, 10) AS x
   WHERE  x % 2 = 0)
    ||
  (SELECT array_agg(x ORDER BY x) AS xs
   FROM   generate_series(1, 10) AS x
   WHERE  NOT(x % 2 = 0))
) AS xs;

-- Thus, NO //ism for this variant of query Q10

EXPLAIN (VERBOSE, ANALYZE)
  SELECT g.g, array_agg(g.a ORDER BY g.a) AS s   -- 10⁴ groups
  FROM   grouped AS g                            -- 10⁶ rows
  GROUP BY g.g;

-----------------------------------------------------------------------
