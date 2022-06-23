
-----------------------------------------------------------------------
-- Overhead of NUMERIC(p,0) ≡ NUMERIC(p) arithmetics
 
SELECT (2::numeric)^100000; -- OK¹ (⚠ SQL syntax allows numeric(1000) only)
 

-- ¹ PostgresSQL actual limits:
--   up to 131072 digits before the decimal point,
--   up to 16383 digits after the decimal point


-- The following two queries to "benchmark" the
-- performance of numeric(.,.) vs. int arithmetics
-- (also see the resulting row width as output by EXPLAIN):

EXPLAIN ANALYZE
-- 1M rows of byte width 32
WITH one_million_rows(x) AS (
  SELECT t.x :: numeric(8,0)
  FROM   generate_series(0, 1000000) AS t(x)
)
SELECT t.x + t.x AS add       -- ⎱ execution time for + (CTE Scan): ~ 255ms
FROM   one_million_rows AS t; -- ⎰



EXPLAIN ANALYZE
-- 1M rows of width 4
WITH one_million_rows(x) AS (
  SELECT t.x :: int
  FROM   generate_series(0, 1000000) AS t(x)
)
SELECT t.x + t.x AS add       -- ⎱ execution time for + (CTE Scan): ~ 130 ms
FROM   one_million_rows AS t; -- ⎰
