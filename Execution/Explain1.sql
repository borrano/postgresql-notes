set track_io_timing = on;

DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int);

INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b,  log(i) as c
FROM generate_series(1, 1000, 1) AS i;
VACUUM FULL ternary;

  
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
SELECT u.* FROM ternary AS u;

--Seq Scan on public.unary u  (cost=0.00..159.75 rows=11475 width=4) (actual time=0.013..0.917 rows=10000 loops=1)
--  Output: a
 
--------------------
-- UPDATE / DELETE / INSERT
EXPLAIN VERBOSE
INSERT INTO ternary(a,b,c)  SELECT t.a, 'Han Solo', t.c  FROM   ternary AS t;

EXPLAIN VERBOSE
UPDATE ternary AS t SET   c = -1  WHERE t.a = 982;
--Update on public.ternary t  (cost=0.00..22.50 rows=0 width=0)
--  ->  Seq Scan on public.ternary t  (cost=0.00..22.50 rows=1 width=14)
--        Output: '-1'::double precision, ctid
-- ctid - 6 + double : 8

EXPLAIN VERBOSE
DELETE FROM ternary AS t WHERE  t.a = 982;
--Delete on public.ternary t  (cost=0.00..22.50 rows=0 width=0)
--  ->  Seq Scan on public.ternary t  (cost=0.00..22.50 rows=1 width=6)
--        Output: ctid
