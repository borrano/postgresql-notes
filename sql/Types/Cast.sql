SELECT t.typname
FROM   pg_catalog.pg_type AS t
WHERE  t.typelem  = 0      -- disregard array element types
  AND  t.typrelid = 0;     -- list non-composite types only
  
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
-- Type casts

-- Runtime type conversion
-- explicit cast
SELECT 6.2 :: int;          -- ➝ 6
SELECT 6.6 :: int;          -- ➝ 7
SELECT date('May 4, 2020'); -- ➝ 2020-05-04 (May the Force ...)

-- Implicit conversion if target type is known (here: schema of T)
INSERT INTO T(a,b,c,d) VALUES (6.2, NULL, 'true', '0');
--                              ↑     ↑      ↑     ↑
--                             int  text  boolean int
-- Explicit cast
INSERT INTO T(a,b,c,d) VALUES (6.2::int, NULL::text, 'true'::boolean, '0'::int);


-- Literal input syntax using '...' (cast from text to any other type):
SELECT booleans.yup :: boolean, booleans.nope :: boolean
FROM   (VALUES ('true', 'false'),
               ('True', 'False'),
               ('t',    'f'),   -- any prefix of 'true'/'false' is OK (whitespace, case do not matter)
               ('1',    '0'),
               ('yes',  'no'),
               ('on',   'off')) AS booleans(yup, nope);

-- May use $‹id›$...$‹id›$ instead of '...'
SELECT $$<t a='42'><l/><r/></t>$$ :: xml;

-- Type casts perform computation, validity checks, and thus are *not* for free:
SELECT $$<t a='42'><l/><r></t>$$ :: xml;
--                      ↑
--              ⚠ no closing tag

-- Implicit cast from text to target during *input conversion*:
DELETE FROM T;

-- convert text values to 
COPY T(a,b,c,d) FROM STDIN WITH (FORMAT CSV, NULL '▢');
1,x,true,10
2,y,true,40
3,x,false,30
4,y,false,20
5,x,true,▢
\.

TABLE T;