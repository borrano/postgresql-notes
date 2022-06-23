DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int NOT NULL, b text NOT NULL, c float);
INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b, log(i) AS c
FROM generate_series(1, 10000000, 1) AS i;

ANALYZE ternary;

EXPLAIN (ANALYZE, VERBOSE)
  SELECT t.a * 3 - t.a * 2    AS a,
         t.a - power(10, t.c) AS diff,
         ceil(t.c / log(2))   AS bits
  FROM   ternary AS t;
-- 1200 ms 

--Seq Scan on public.ternary t  (cost=0.00..43.90 rows=1130 width=20)
--  Output: ((a * 3) - (a * 2)), ((a)::double precision - power('10'::double precision, c)), ceil((c / '0.3010299956639812'::double precision))
 
-- explicity casting introduced
-- some constant folding is executed - log(2) is evaluated

 
--------------------
--- JIT compilation
show max_parallel_workers_per_gather;
set jit = off;                  
EXPLAIN (ANALYZE, VERBOSE)
  SELECT t.a * 3 - t.a * 2    AS a,
         t.a - power(10, t.c) AS diff,
         ceil(t.c / log(2))   AS bits
  FROM   ternary AS t;
-- 1320 ms

set jit = on;                      -- back to the default
set jit_above_cost = 1;           -- ⚠️ ridiculously low, we risk costly investment into
set jit_optimize_above_cost = 1;  --    JIT compilation for queries that are cheap to execute w/o JIT

-- WITH JIT forced, JIT compilation makes for almost 100%(!) of the execution time
-- for the (cheap) query below.  Observing a ≈ 40 × slow down (evaluate multiple
-- times for stable timings).
EXPLAIN ANALYZE VERBOSE
  SELECT t.a * 3 - t.a * 2    AS a,
         t.a - power(10, t.c) AS diff,
         ceil(t.c / log(2))   AS bits
  FROM   ternary AS t LIMIT 1000;
-- 50 ms ? why is llvm generation time is 10ms 
--  


EXPLAIN ANALYZE VERBOSE
  SELECT t.a * 3 - t.a * 2    AS a,
         t.a - power(10, t.c) AS diff,
         ceil(t.c / log(2))   AS bits
  FROM   ternary AS t LIMIT 1000;
-- 0.045 ms
reset jit_above_cost  ;           -- ⚠️ ridiculously low, we risk costly investment into
reset jit_optimize_above_cost  ;  --    JIT compilation for queries that are cheap to execute w/o JIT

-----------------------------
--- Predicate evaluation

TRUNCATE ternary;
INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b, log(i) AS c
FROM generate_series(1, 1000, 1) AS i;
ANALYZE ternary;
 
EXPLAIN ANALYZE VERBOSE  -- also try: EXPLAIN ANALYZE
  SELECT t.a, t.b
  FROM   ternary AS t
  WHERE  t.a % 2 = 0 AND t.c < 2;
--   Filter: ((t.c < '2'::double precision) AND ((t.a % 2) = 0))
-- mod is evaluated later

-- (cost=0.00..27.50 rows=1 width=37) 
-- (actual time=0.011..0.119 rows=33 loops=1)
-- predicted row : 1 
-- actual row : 33
-- mod operation confuses postgresql row estimation

-----------------------------------------------------------------------
-- Heuristic predicate simplification

-- ➊ Remove double NOT() + De Morgan:

EXPLAIN VERBOSE
  SELECT t.a, t.b FROM   ternary AS t
  WHERE  NOT(NOT(NOT(t.a % 2 = 0 AND t.c < 1)));
--   Filter: (((t.a % 2) <> 0) OR (t.c >= '1'::double precision))


-- ➋ Inverse distributivity of AND:

EXPLAIN VERBOSE
  SELECT t.a, t.b  FROM   ternary AS t
  WHERE (t.a % 2 = 0 AND t.c < 1) OR (t.a % 2 = 0 AND t.c > 2);
--   Filter: (((t.c < '1'::double precision) OR (t.c > '2'::double precision)) 
--   AND ((t.a % 2) = 0))

-- https://www.postgresql.org/docs/current/catalog-pg-operator.html
-- BASIC cost information for operators
SELECT * FROM pg_operator as o, pg_type as t 
WHERE typname = 'int8' AND o.oprleft = t.oid AND oprname IN ('<', '%') ;

SELECT * FROM pg_proc WHERE proname = 'scalarltsel' ;



EXPLAIN ANALYZE
 SELECT *
 FROM ternary  AS t
 WHERE length(btrim(t.b, '0123456789')) < length(t.b)  -- costly clause
    OR t.a % 1000 <> 0;                                -- cheap clause
--   Filter: ((length(btrim(b, '0123456789'::text)) < length(b)) OR ((a % 1000) <> 0))
-- Execution Time: 0.553 ms

EXPLAIN ANALYZE
 SELECT *
 FROM   ternary AS t
 WHERE  t.a % 1000 <> 0                                  -- cheap clause
    OR  length(btrim(t.b, '0123456789')) < length(t.b);  -- costly clause
-- Filter: (((a % 1000) <> 0) OR (length(btrim(b, '0123456789'::text)) < length(b)))
-- Execution Time: 0.099 ms