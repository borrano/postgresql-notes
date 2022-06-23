
-- LOCKS when building index - concurrently 
DROP TABLE IF EXISTS indexed;
CREATE TABLE indexed (a int  ,
                      b text,
                      c numeric(3,2));
INSERT INTO indexed(a,b,c)
        SELECT i, md5(i::text), sin(i)
        FROM   generate_series(1,10000) AS i;

DROP INDEX IF EXISTS indexed_b;
-- ➊ Prepare (a,c) index.  Make sure that all rows on all
--   pages are indeed visible (VACCUM).
CREATE INDEX indexed_b ON indexed USING btree (b);
 
-- when building index execute it from psql
select mode, granted from pg_locks where relation = 'indexed'::regclass;

-- sharelock allows reads but denies all updates

--    mode    | granted 
-- -----------+---------
--  ShareLock | t
--  ShareLock | t

create index concurrently indexed_b on indexed USING btree(b);
-- ShareUpdateExclusiveLock	true
-- ShareUpdateExclusiveLock allow reads and updates but you cannot change structure of table.

-------------------------------------------------------------------------------
-- performance difference which is faster?
-- create table - insert all - then create table

DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int, b text, c numeric(3,2));  -- no PRIMARY KEY!
-- ➋ Populate table
--   (rows probably placed in heap file ascending 'a' order)

-- 13.1 seconds
EXPLAIN (ANALYZE)
INSERT INTO ternary(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(1,10000000) AS i;
-- ➌ Create index, then loads all rows (ascending key order ⇒ bulk load fast path!)
VACUUM ternary;
-- 1.89
CREATE INDEX ternary_a ON ternary USING btree (a);  -- (*)

-- 2. Create index, then populate table

-- ➊ Create empty table (no index created yet)
DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int, b text, c numeric(3,2));  -- no PRIMARY KEY!
-- ➋ Create empty index
CREATE INDEX ternary_a ON ternary USING btree (a);
-- ➌ Populate table (also populates index)

-- 18.3 seconds
EXPLAIN ANALYZE
INSERT INTO ternary(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(1,10000000) AS i;


-- Now make life hard for PostgreSQL and insert keys in *descending*
-- order, we cannot benefit from the bulk loading fast path.

-- ➊ Create empty table (no index created yet)
DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int, b text, c numeric(3,2));
-- ➋ Populate table
--   (rows probably placed in heap file descending 'a' order)
-- 13.3 seconds
EXPLAIN ANALYZE
INSERT INTO ternary(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(10000000,1,-1) AS i; -- descending order keys in heap file
VACUUM ternary;

-- 2.4 seconds
-- ➌ Create index, then loads all rows (descending key order)
CREATE INDEX ternary_a ON ternary USING btree (a);  -- slower than (*)


-- Resulting index is not clustered indeed (row order ≠ index key 'a' order)
SELECT i.ctid, i.*
FROM   ternary AS i
LIMIT  10;

DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int, b text, c numeric(3,2));
-- ➋ Populate table
--   (rows probably placed in heap file descending 'a' order)
-- 6.5 seconds
EXPLAIN ANALYZE
INSERT INTO ternary(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(5000000,1,-1) AS i; -- descending order keys in heap file

-- 2.5 seconds -- twice slower than ordered column
-- ➌ Create index, then loads all rows (descending key order)
CREATE INDEX ternary_c ON ternary USING btree (c);  -- slower than (*)

DROP TABLE IF EXISTS ternary;



-----------------------------------------------------------------------
-- Partitioned B+ trees

-- Using low(!)-selectivity key prefixes in a B+Tree to implement
-- fast bulk inserts of data partitions and controlled merging of
-- partitions
--
-- See Goetz Graefe (2003), "Partitioned B-trees - a user's guide"
-- https://pdfs.semanticscholar.org/78ce/cd5f738c26ddefb3633f8a50bd6397ebc8dc.pdf

-- ➊ Create table of partitions, main/default partition is #0
-- 2.2
-- decrease shared_buffers

DROP TABLE IF EXISTS parts;
CREATE TABLE parts (a int, b text, c numeric(3,2));

ALTER TABLE parts
  ADD COLUMN p int NOT NULL CHECK (p >= 0) DEFAULT 0;

INSERT INTO parts(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(1,1000000) AS i;

CREATE INDEX parts_p_a ON parts USING btree (p, a);
CLUSTER parts USING parts_p_a;
ANALYZE parts;

-- 0.28
-- ➋ Bulk insert of a new partition #1 of data (uses B+Tree fast bulk loading)
EXPLAIN ANALYZE
INSERT INTO parts(p,a,b,c)
  --     🠷
  SELECT 1, random() * 1000000, md5(i::text), sin(i)
  FROM   generate_series(1,100000) AS i;

-- 0.28
-- ➌ Bulk insert of a new partition #2 of data (uses B+Tree fast bulk loading
INSERT INTO parts(p,a,b,c)
  SELECT 2, random() * 1000000, md5(i::text), sin(i)
  FROM   generate_series(1,100000) AS i;

ANALYZE parts;

-- ➍ Predicates that refer to column "a" will still be evaluated
--   using the "parts_p_a" index.  Rows participating in the query
--   (e.g., all rows/only recent rows/...) can be selected on a
--   by-partition basis.
--
--   (For an explanation of the BitmapOr operator you will find in
--    the plan, check DB2 Video #53.)
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT MAX(p.c)
  FROM   parts AS p
  WHERE  (p.p = 0 OR p.p = 1) AND p.a BETWEEN 0 AND 42;
  --     └──────────────────┘     └──────────────────┘
  --      select partition(s)      original predicate

-- 0.89
-- ➎ Merge partition #1, #2 into main partition
UPDATE parts AS p
SET    p = 0 -- 🠴 merge partition 1 into main partition 0
WHERE  p.p = 1;

UPDATE parts AS p
SET    p = 0 -- 🠴 merge partition 2 into main partition 0
WHERE  p.p = 2;

------------------
-- 1.65

DROP TABLE IF EXISTS parts;
CREATE TABLE parts (a int, b text, c numeric(3,2));

INSERT INTO parts(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(1,1000000) AS i;

CREATE INDEX parts_a ON parts USING btree (a);

 
-- 0.72
EXPLAIN ANALYZE
INSERT INTO parts(a,b,c)
  SELECT random() * 1000000, md5(i::text), sin(i)
  FROM   generate_series(1,100000) AS i;
 
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT MAX(p.c)
  FROM   parts AS p
  WHERE   p.a BETWEEN 0 AND 42;
