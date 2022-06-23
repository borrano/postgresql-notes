DROP TABLE IF EXISTS T;
CREATE TABLE T (a int PRIMARY KEY, b text, c boolean, d int);

INSERT INTO T VALUES
  (1, 'x',  true, 10),
  (2, 'y',  true, 40),
  (3, 'x', false, 30),
  (4, 'y', false, 20),
  (5, 'x',  true, NULL);


SELECT t.* FROM T AS t
TABLE T;

-----------------------------------------------------------------------
-- column aliasing - values
-- default name is column1

VALUES (1), (2);

-- values in from must have an alias

SELECT * FROM 
(VALUES (1), (2)) as v 
WHERE column1 > 1;


SELECT t.*
FROM   (VALUES (false, 0),
               (true,  1)) AS t(truth, "binary");

-----------------------------------------------------------------------
-- FROM computes Cartesian product of row bindings

SELECT t1.*, t2.*
FROM   T AS t1,
       T AS t2(a2, b2, c2, d2);


SELECT onetwo.num, t.*
FROM   (VALUES ('➊'), ('➋')) AS onetwo(num),
       T AS t;

-----------------------------------------------------------------------
-- WHERE discards row bindings

SELECT onetwo.num, t.*
FROM   (VALUES ('➊'), ('➋')) AS onetwo(num), T AS t
WHERE  onetwo.num = '➋';

SELECT t.*
FROM   T AS t
WHERE  t.a * 10 = t.d;


SELECT t.*
FROM   T AS t
WHERE  t.c;  -- ≡ WHERE t.c = true 😕

SELECT t1.a, t1.b || ',' || t2.b AS b₁b₂  -- to illustrate: add ..., t2.a
FROM   T AS t1, T AS t2
WHERE  t1.a BETWEEN t2.a - 1 AND t2.a + 1;


-----------------------------------------------------------------------
---- NULL comparison

SELECT t.*
FROM   T AS t
WHERE  t.d IS NULL;

-- a=NULL - equals to NULL produces null
SELECT t.d, t.d IS NULL, t.d = NULL, t.d = 1   -- ⚠ t.d = NULL yields NULL ≠ true
FROM   T AS t;
-----------------------------------------------------------------------
---- Subqueries 

-- scalar subquery
SELECT 2 + (SELECT t.d AS _
            FROM   T AS t
            WHERE  t.a = 2)  AS "The Answer";   -- ⚠ t.a = 0,  t.a > 2

--- correlation
EXPLAIN
SELECT t1.*
FROM   T AS t1
WHERE  t1.b <> (SELECT t2.b
                FROM   T AS t2
                WHERE  t1.a = t2.a);

--Seq Scan on t t1  (cost=0.00..6.38 rows=5 width=11)
--Filter: (b <> (SubPlan 1))
--SubPlan 1
--  ->  Seq Scan on t t2  (cost=0.00..1.06 rows=1 width=2)
--        Filter: (t1.a = a)

-----------------------------------------------------------------------
--- Ordering
SELECT t.*
FROM   T AS t
ORDER BY t.d ASC NULLS FIRST;  -- default: NULL larger than any non-NULL value

SELECT t.*
FROM   T AS t
ORDER BY t.b DESC, t.c;        -- default: ASC, false < true

SELECT t.*, t.d / t.a AS ratio
FROM   T AS t
ORDER BY ratio;                -- may refer to computed columns


VALUES (1, 'one'),
       (2, 'two'),
       (3, 'three')
ORDER BY column1 DESC;


SELECT t.*
FROM   T AS t
ORDER BY t.a DESC
OFFSET 1          -- skip 1 row
LIMIT 3;          -- fetch ≤ 3 rows (≡ FETCH NEXT 3 ROWS ONLY)

-----------------------------------------------------------------------
-- Duplicate removal (DISTINCT ON, DISTINCT)

SELECT DISTINCT ON (t.c) t.*
FROM   T AS t; -- no error but not recommended

-- Keep the d-smallest row for each of the two false/true groups
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t
ORDER BY t.c, t.d ASC;


-- In absence of ORDER BY, we get *any* representative from the
-- two groups (PostgreSQL still uses sorting on t.c, however):
EXPLAIN
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t;

-- An "incompatible" clause lets PostgreSQL choke:
-- error 
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t
ORDER BY t.a;

EXPLAIN ANALYZE
SELECT DISTINCT ON (t.c) t.*
FROM   T AS t;  -- it will result in sort and unique 

-- Unique  (cost=1.11..1.13 rows=2 width=11) (actual time=0.030..0.033 rows=2 loops=1)
--   ->  Sort  (cost=1.11..1.12 rows=5 width=11) (actual time=0.030..0.030 rows=5 loops=1)
--         Sort Key: c
--         Sort Method: quicksort  Memory: 25kB
--         ->  Seq Scan on t  (cost=0.00..1.05 rows=5 width=11) (actual time=0.005..0.005 rows=5 loops=1)
-- Planning Time: 0.144 ms
-- Execution Time: 0.060 ms

-----------------------------------------------------------------------
-- Aggregation

-- Aggregate all rows in table T, resulting table has one row (even
-- if no rows are supplied):

SELECT COUNT(*)          AS "#rows",
       COUNT(t.d)        AS "#d",
       SUM(t.d)          AS "∑d",
       MAX(t.b)          AS "max(b)",
       bool_and(t.c)     AS "∀c",
       bool_or(t.d = 42) AS "∃d=42"
FROM   T AS t
WHERE  true;


-- ordered aggregate
SELECT string_agg(t.a :: text, ',' ORDER BY t.d) AS "all a" 
FROM   T AS t;
-- filtered aggregate
SELECT SUM(t.d) FILTER (WHERE t.c) AS picky,
       SUM(t.d)                    AS "don't care"
FROM   T As t;
-- filtered aggregate - different implementation
SELECT SUM(CASE WHEN t.c THEN t.d ELSE 0 END) AS picky,
       SUM(t.d) AS "don't care"
FROM   T As t;
--- pivoting with filtered aggregate
SELECT SUM(t.d) FILTER (WHERE t.b = 'x')            AS "∑d in region x",
       SUM(t.d) FILTER (WHERE t.b = 'y')            AS "∑d in region y",
       SUM(t.d) FILTER (WHERE t.b NOT IN ('x','y')) AS "∑d elsewhere"
FROM   T As t;
-- Unique aggregate
SELECT COUNT(DISTINCT t.c) AS "#distinct non-NULL",  -- there are only two distinct Booleans...
       COUNT(t.c)          AS "#non-NULL"
FROM   T as t;

-- Unique aggregate
EXPLAIN (ANALYZE, VERBOSE)
SELECT COUNT(DISTINCT t.c) AS "#distinct non-NULL",  -- there are only two distinct Booleans...
       COUNT(t.c)          AS "#non-NULL"
FROM   T as t;

-----------------------------------------------------------------------
-- Grouping

-- Aggregates are evaluated once per (qualifying) group:

SELECT t.b                           AS "group",
       COUNT(*)                      AS size,
       SUM(t.d)                      AS "∑d",
       bool_and(t.a % 2 = 0)         AS "∀even(a)",   --  true in the 'x' group, false in the 'y' group
       string_agg(t.a :: text, ';')  AS "all a"
FROM   T AS t
GROUP BY t.b;
HAVING COUNT(*) > 2; -- filtering groups

SELECT -- t.a -- error? grouping criterion is t.a %2 not t.a
       t.a % 2 AS "a odd?",
       COUNT(*) AS size
FROM   T AS t
GROUP BY t.a % 2;

SELECT t.b AS "group",
       t.a % 2 AS "a odd?" -- constant in the 'x'/'y' groups, but PostgreSQL doesn't know...
FROM   T AS t
GROUP BY t.b, t.a % 2;

-----------------------------------------------------------------------
-- Bag/set operations

-- For all bag/set operations, the lhs/rhs argument tables need to
-- contribute compatible rows:
-- • row widths must match
-- • field types in corresponding columns must be cast-compatible
-- • the row type of the lhs argument determines the result's
--   field types and names

SELECT t.* FROM   T AS t WHERE  t.c
  UNION ALL   -- ≡ UNION (since both queries are disjoint: key t.a included)
SELECT t.* FROM   T AS t WHERE  NOT t.c;


SELECT t.b FROM   T AS t WHERE  t.c
  UNION ALL       -- ≠ UNION (queries contribute duplicate rows)
SELECT t.b FROM   T AS t WHERE  NOT t.c;


-- Which subquery q contributed what to the result?
SELECT 1 AS q, t.b FROM   T AS t WHERE  t.c
  UNION ALL
SELECT 2 AS q, t.b FROM   T AS t WHERE  NOT t.c;


SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₁ contributes 2 × 'x', 1 × 'y'
WHERE  t.c        -- ⎭
  EXCEPT ALL
SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₂ contributes 1 × 'x', 1 × 'y'
WHERE  NOT t.c;   -- ⎭


-- EXCEPT ALL is *not* commutative (this yields ∅):
SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₂ contributes 1 × 'x', 1 × 'y'
WHERE  NOT t.c    -- ⎭
  EXCEPT ALL
SELECT t.b        -- ⎫
FROM   T AS t     -- ⎬  q₁ contributes 2 × 'x', 1 × 'y'
WHERE  t.c;       -- ⎭

------------
--- ANY and all 

SELECT *
FROM T
WHERE a = ANY(VALUES (1), (2), (3)); 

SELECT *
FROM T
WHERE a <= ALL(VALUES (3), (4), (2)); 

-----------------------------------------------------------------------
-- Syntactic sugar: GROUPING SETS/ROLLUP/CUBE

-- fact table
DROP TABLE IF EXISTS prehistoric;
CREATE TABLE prehistoric (class        text,
                          "herbivore?" boolean,
                          legs         int,
                          species      text);

INSERT INTO prehistoric VALUES
  ('mammalia',  true, 2, 'Megatherium'),
  ('mammalia',  true, 4, 'Paraceratherium'),
  ('mammalia', false, 2, NULL),           -- no known bipedal carnivores
  ('mammalia', false, 4, 'Sabretooth'),
  ('reptilia',  true, 2, 'Iguanodon'),
  ('reptilia',  true, 4, 'Brachiosaurus'),
  ('reptilia', false, 2, 'Velociraptor'),
  ('reptilia', false, 4, NULL);           -- no known quadropedal carnivores

SELECT p.class,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use COALESCE(p.species, '?'))
FROM   prehistoric AS p
GROUP BY GROUPING SETS ((class), ("herbivore?"), (legs));

-- Equivalent to GROUPING SETS ((class), ("herbivore?"), (legs))
SELECT p.class,
       NULL :: boolean             AS "herbivore?", -- ⎱  NULL is polymorphic ⇒ PostgreSQL
       NULL :: int                 AS legs,         -- ⎰  will default to type text
       string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY p.class
  UNION ALL
SELECT NULL :: text                AS class,
       p."herbivore?",
       NULL :: int                 AS legs,
       string_agg(p.species, ',' ) AS species
FROM   prehistoric AS p
GROUP BY p."herbivore?"
  UNION ALL
SELECT NULL :: text                AS class,
       NULL :: boolean             AS "herbivore?",
       p.legs AS legs,
       string_agg(p.species, ', ') AS species
FROM   prehistoric AS p
GROUP BY p.legs;

-- ROLLUP
SELECT p.class,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use COALESCE(p.species, '?'))
FROM   prehistoric AS p
GROUP BY ROLLUP (class, "herbivore?", legs);


-- all combinations
-- cube
SELECT p.class,
       p."herbivore?",
       p.legs,
       string_agg(p.species, ', ') AS species  -- string_agg ignores NULL (may use coalesce(p.species, '?'))
FROM   prehistoric AS p
GROUP BY CUBE (class, "herbivore?", legs);


-----------------------------------------------
--- Common table expressions

DROP TABLE IF EXISTS dinosaurs;
CREATE TABLE dinosaurs (species text, height float, length float, legs int);

INSERT INTO dinosaurs(species, height, length, legs) VALUES
  ('Ceratosaurus',      4.0,   6.1,  2),
  ('Deinonychus',       1.5,   2.7,  2),
  ('Microvenator',      0.8,   1.2,  2),
  ('Plateosaurus',      2.1,   7.9,  2),
  ('Spinosaurus',       2.4,  12.2,  2),
  ('Tyrannosaurus',     7.0,  15.2,  2),
  ('Velociraptor',      0.6,   1.8,  2),
  ('Apatosaurus',       2.2,  22.9,  4),
  ('Brachiosaurus',     7.6,  30.5,  4),
  ('Diplodocus',        3.6,  27.1,  4),
  ('Supersaurus',      10.0,  30.5,  4),
  ('Albertosaurus',     4.6,   9.1,  NULL),  -- Bi-/quadropedality is
  ('Argentinosaurus',  10.7,  36.6,  NULL),  -- unknown for these species.
  ('Compsognathus',     0.6,   0.9,  NULL),  --
  ('Gallimimus',        2.4,   5.5,  NULL),  -- Try to infer pedality from
  ('Mamenchisaurus',    5.3,  21.0,  NULL),  -- their ratio of body height
  ('Oviraptor',         0.9,   1.5,  NULL),  -- to length.
  ('Ultrasaurus',       8.1,  30.5,  NULL);  --

WITH T(legs, ratio) as (
       SELECT d.legs, AVG(d.height / d.length) 
       FROM dinosaurs as d 
       WHERE d.legs IS NOT NULL
       GROUP BY d.legs
)
SELECT DISTINCT ON (d.species) d.species, t.legs, abs(t.ratio - (d.height / d.length))
FROM dinosaurs as d, T as t
WHERE d.legs IS NULL
ORDER BY d.species ASC, 3 ASC;


 