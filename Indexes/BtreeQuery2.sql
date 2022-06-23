----------------------------
-- In this file Which index is used, correlation, selectivity

-- Recreate and populate playground table "indexed",
-- establish two B+Tree indexes on columns "a" and "c"
DROP TABLE IF EXISTS indexed;
CREATE TABLE indexed (a int ,
                      b text,
                      c numeric(3,2));
 
INSERT INTO indexed(a,b,c)
        SELECT i, md5(i::text), sin(i)
        FROM   generate_series(1,1000000) AS i;

ANALYZE indexed;
 
-----------------------------------
--- Index - query matching

-- ➊ In the absence of an function-based index, this query
--   will be evaluated by a Seq Scan
-- Seq scan 
-- Execution Time: 156.407 ms
-- Buffers: shared hit=9346

CREATE INDEX indexed_a ON indexed USING btree (a);
CREATE INDEX indexed_c ON indexed USING btree (c);

EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a
  FROM   indexed AS i
  WHERE  degrees(asin(i.c)) = 90;


-- NB:
-- degrees(x) = y ⇔ x = (y / 180.0) * π
-- asin(x)    = y ⇔ x = sin(y)
SET max_parallel_workers_per_gather = 0;

-- ➋ Retry the query with column i.c isolated:
-- Still seq scan
-- Filter: ((i.c)::double precision = '1'::double precision)
-- because of casting we cannot use the index
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a
  FROM   indexed AS i
  WHERE  i.c = sin((90 / 180.0) * pi());


-- ➌ Another retry, now cast the compared value to the declared
--   type numeric(3,2) of column "c"
-- index is used 
-- bitmap heap scan 
-- 16.8 ms
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a
  FROM   indexed AS i
  WHERE  i.c = sin((90 / 180.0) * pi()) :: numeric(3,2);

-----------------------------------------------------------------------
-- EXPRESSION INDEXES 

-- An expression-based index will match the original query ➊ above
--                                                expression over column "c"
--                                                             ↓
CREATE INDEX indexed_deg_asin_c ON indexed USING btree (degrees(asin(c)));
ANALYZE indexed;
 
-- ➊ The original query again

-- BITMAP INDEX SCAN using indexed_deg_asin_c
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a
  FROM   indexed AS i
  WHERE  degrees(asin(i.c)) = 90;  -- matches indexed_deg_asin_c




-- Other useful expression-based indexes in practice:

-- CREATE INDEX ... USING btree (lower(lastname))
--
-- Supports queries like:
--
--   SELECT ...
--   FROM   ...
--   WHERE  lower(t.lastname) = lower('Kenobi')

-- CREATE INDEX ... USING btree (firstname || ' ' || lastname)
 
-- Expression-based indexes must be defined over deterministic
-- expressions (whose value at index creation time and query
-- time are always equal):

DROP FUNCTION IF EXISTS get_age(date);
CREATE FUNCTION get_age(d_o_b date) RETURNS int AS
$$
  SELECT extract(years from age(now(), d_o_b)) :: int
$$
LANGUAGE SQL;

DROP TABLE IF EXISTS people;
CREATE TABLE people (name text, birthdate date);
CREATE INDEX people_age ON people
  USING btree (get_age(birthdate));  -- ⚠️ illegal

DROP INDEX indexed_c;
DROP INDEX indexed_deg_asin_c;
ALTER TABLE indexed DROP CONSTRAINT indexed_a;

-----------------------------------------------------------------------
-- COMPOSITE INDEXES 


-- PostgreSQL uses/ignores a composite index based
-- on how a filter predicate matches the index order

-- Clean-up indexes on tabled "indexed"

-- ➊ Even clean-up the primary key index on column "a",
--   then build a composite (c,a) B+Tree index
CREATE INDEX indexed_c_a ON indexed USING btree (c,a);
ANALYZE indexed;

-- indexed     | r       |     9346
-- indexed_c_a | i       |     3849
---- Check table and index size (# of heap pages):
SELECT relname, relkind, relpages
FROM   pg_class WHERE relname LIKE 'indexed%';

-- bitmap heap scan
-- ➌ Evaluate query with predicate matching the (c,a) index:
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  WHERE  i.c = 0.42;   -- 🠴 (c) is a prefix of (c,a)

-- sequential scan
-- ➍ Evaluate query with predicate NOT matching the (c,a) index:
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  WHERE  i.a = 42;   -- 🠴 (a) not a prefix of (c,a)


-- ➎ Force PostgreSQL to use the (c,a) index despite the non-matching
--   predicate: will touch (almost) all pages of the index.
set enable_seqscan = off;
set enable_indexscan = off;


EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.*
  FROM   indexed AS i
  WHERE  i.a = 42;   -- 🠴 (a) not a prefix of (c,a)


reset enable_seqscan;
reset enable_indexscan;

-----------------------------------------------------------------------
-- Supporting predicates over multiple columns with a composote
-- index.

-- ➊ Table "indexed" now has composite (c,a) and (a,c) indexes
CREATE INDEX indexed_a_c ON indexed USING btree(a,c);
ANALYZE indexed;


-- how selectivity of predicates changes index usage
 
-- ➋ Modify parameter m to render p2 more and more selective such that
--   PostgreSQL switches from using index (c,a) to (a,c).  Can perform
--   binary search regarding m to find switch point.

-- Index Scan using indexed_a_c
EXPLAIN
  SELECT i.b
  FROM   indexed AS i
  WHERE  i.c BETWEEN 0.00 AND 0.01  -- p1 more selective
    AND  i.a BETWEEN 0 AND 1000;      -- p2 with m = 10000 less selective

-- Bitmap Index Scan on indexed_c_a
EXPLAIN
  SELECT i.b
  FROM   indexed AS i
  WHERE  i.c BETWEEN 0.00 AND 0.01  -- p1 more selective
    AND  i.a BETWEEN 0 AND 100000;      -- p2 with m = 10000 less selective

DROP INDEX IF EXISTS indexed_a_c;
DROP INDEX IF EXISTS indexed_c_a;

-----------------------------------------------------------------------
-- Evaluate disjunctive predicates on multiple columns using
-- multiple separate indexes.

-- ➊ Prepare separate indexes on columns "a" and "c"

CREATE INDEX indexed_a ON indexed USING btree (a);
CREATE INDEX indexed_c ON indexed USING btree (c);
ANALYZE indexed;
 

-- BitmapOr 8.6 ms
-- ➋ Perform query featuring a disjunctive predicate
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.b
  FROM   indexed AS i
  WHERE  i.c BETWEEN 0.00 AND 0.01
     OR  i.a BETWEEN 0 AND 4000;

-- (See ➍ in the discussion of Partitioned B+Trees above for another
--  query example that employs BitmapOr.)
-- ➌ BitmapOr + two Bitmap Index Scans indeed pays off
-- 86 ms seq scan
set enable_bitmapscan = off;
SET max_parallel_workers_per_gather = 0;

EXPLAIN (VERBOSE, ANALYZE)
  SELECT i.b
  FROM   indexed AS i
  WHERE  i.c BETWEEN 0.00 AND 0.01
     OR  i.a BETWEEN 0 AND 4000;

reset enable_bitmapscan;


-----------------------------------------------------------------------
-- String patterns (`LIKE`) influence predicate
-- selectivity and the resulting (index) scans chosen by PostgreSQL.

-- Create index on column "b" of table "indexed" that supports
-- pattern matching via LIKE
CREATE INDEX indexed_b ON indexed USING btree (b text_pattern_ops);
ANALYZE indexed;

\d indexed

-- Recall the contents of column "b"
SELECT i.b
FROM   indexed AS i
ORDER BY i.b
LIMIT  10;

-- ➊ Leading % wildcard: low selectivity
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   indexed AS i
  WHERE  i.b LIKE '%42';


-- ➋ Leading character: medium selectivity
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   indexed AS i
  WHERE  i.b LIKE 'a%42';


-- ➌ Leading characters: selectivity increases with length of
--   character sequence
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a, i.b
  FROM   indexed AS i
  WHERE  i.b LIKE 'abc%42';


-----------------------------------------------------------------------
-- Cconstruction and matching of a *partial* index on
-- table "indexed".

-- ➊ Create partial index: a row is "hot" if its c value exceeds 0.5
CREATE INDEX indexed_partial_a ON indexed USING btree (a)
  WHERE c >= 0.5;
ANALYZE indexed;

\d indexed;


-- ➋ Check: the partial index is indeed smaller than the regular/full indexes
SELECT relname, relkind, relpages
FROM   pg_class
WHERE  relname LIKE 'indexed%';

SELECT (100.0 * COUNT(*) FILTER (WHERE i.c >= 0.5) / COUNT(*))::numeric(4,2) AS "% of hot rows",
       (100.0 * 922                                / 2745)    ::numeric(4,2) AS "% of index size"
FROM indexed AS i;


-- ➌ Do these queries match the partial index?  Check the resulting
--   "Index Cond" and "Filter" predicates in the EXPLAIN outputs.
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a
  FROM   indexed AS i
  WHERE  c >= 0.6 AND a < 1000;


EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a
  FROM   indexed AS i
  WHERE  c >= 0.5 AND a < 1000;


EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.a
  FROM   indexed AS i
  WHERE  c >= 0.4 AND a < 1000;


