

DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int NOT NULL, b text NOT NULL, c float);
INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b,  
    CASE
        WHEN i % 10 = 0 THEN NULL
        ELSE log(i)
    END AS c
FROM generate_series(1, 1000, 1) AS i;

 
ANALYZE ternary;

EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
SELECT * FROM ternary AS t;
-- Seq Scan on public.ternary t  (.. width=45) 
-- Tuple size: 4 + (32 + 1) + 8 = 45

-- page layout:
-- upper - lower pointers
-- page header : 24 bytes
-- line pointers : 4 bytes
-- tuples 
-- special space (end of the block) - only used in index pages - in heap files: size 0

-- a tuple is 45 + 4 bytes. 
CREATE EXTENSION IF NOT EXISTS pageinspect;
SELECT * FROM page_header(get_raw_page('ternary', 0));
-- lower : 452
-- upper : 488
-- lsn 
SELECT * FROM page_header(get_raw_page('ternary', 9));
-- lower 172, upper 5528
SELECT (172 - 24) / 4; -- 37 line pointers in use

VACUUM ternary;
SELECT * FROM pg_freespace('ternary');



SELECT * FROM ShowHeap('ternary', 0) LIMIT 10;
-- lp_len : 72 total size of tuple
-- t_hoff: 24 bytes tuple header
-- t_infomask2 : how many attributes


---------------------------

-- alignment and lengths

SELECT a .attnum,  a .attname,  a .attlen,  a .attstorage,  a .attalign,  a .attrelid
FROM pg_attribute AS a
WHERE a .attrelid = 'ternary'::regclass    
ORDER BY a .attnum;

-- attlen: -1 : variable size
-- attstorage: p inside page, x can be toast attr
-- attalign: d - double:8, i : integer - 4


DROP TABLE IF EXISTS padded;
DROP TABLE IF EXISTS packed;
CREATE TABLE padded (d int2, a int8, e int2, b int8, f int2, c int8); -- 48 bytes
CREATE TABLE packed (a int8, b int8, c int8, d int2, e int2, f int2); -- 30 (+2) bytes

INSERT INTO padded(d, a, e, b, f, c)
SELECT 0,  i,  0,  i,  0,  i
FROM generate_series(1, 1000000) AS i;

INSERT INTO packed(a, b, c, d, e, f)
SELECT i,  i,  i,  0,  0,  0
FROM generate_series(1, 1000000) AS i;

VACUUM padded;
SELECT COUNT(*) FROM pg_freespace('padded'); -- 9346

VACUUM packed;
SELECT COUNT(*) FROM pg_freespace('packed'); -- 7353

SELECT Count(*) FROM ShowHeap('padded', 0)  ; -- 107
SELECT Count(*) FROM ShowHeap('packed', 0)  ; -- 136

SELECT lp_len FROM ShowHeap('padded', 0) LIMIT 1 ; -- 72  -- 45 + 24
SELECT lp_len  FROM ShowHeap('packed', 0) LIMIT 1 ; -- 54 -- 30 + 24

EXPLAIN VERBOSE SELECT p. *FROM padded AS p; 
-- Seq Scan on public.padded p  (cost=0.00..19345.78 rows=999978 width=30)

EXPLAIN VERBOSE SELECT p. * FROM packed AS p;
-- Seq Scan on public.packed p  (cost=0.00..17352.92 rows=999992 width=30)

-- width does not account for padding but cost metric is more in padded table.
 

-------------------------------------
-- representation of nulls 
  
SELECT * FROM ShowHeap('ternary', 0) OFFSET 9 LIMIT 1;
-- lp_len is 61 in rows that have c null value
-- raw_flags : HEAP_HASNULL
-- t_bits : 11000000 -- not null | not null | null
-- null bitmap has (no of columns / 8) bits

-- what happens when all columns are null 
DROP TABLE IF EXISTS padded;
CREATE TABLE padded (d int2, a int8, e int2, b int8, f int2, c int8); -- 48 bytes

INSERT INTO padded(a, b, c, d, e, f)
VALUES (NULL, NULL, NULL, NULL, NULL, NULL);
SELECT * FROM ShowHeap('padded', 0);
-- lp_len is 24 - no data stored 


----------------------
-- Column decoding

-- C routine slot_getattr(), excerpt of PostgreSQL source code file
-- src/backend/access/common/heaptuple.c:

-- attnum - column number 
-- virtual attribute or not (ctid) attnum <= 0 
-- check cache - left to right decoding if we already decoded the attr
-- check null map - return null

INSERT INTO ternary(a, b, c)
SELECT i AS a,
  md5(i::text) AS b,
  CASE
    WHEN i % 10 = 0 THEN NULL
    ELSE log(i)
  END AS c
FROM generate_series(1, 10000000, 1) AS i;

-- Does the evaluation time for an arbitrary projection (column order
-- c, b, a) differ from the retrieval in storage order (a, b, c)?
EXPLAIN (VERBOSE, ANALYZE)
SELECT t.a
FROM ternary AS t;

EXPLAIN (VERBOSE, ANALYZE)
SELECT t. * -- also OK: t.a, t.b, t.c ≡ t.*,
FROM ternary AS t; 
-- t.* is supported by a fast-path in PostgreSQL C code
-- faster to get all columns because no column decoding is neccessary


---------------------------------------
-- xmin, xmax, ROW VISIBILITY

-- ➋ check row header contents before update
SELECT * FROM ShowHeap('Ternary', 9);
-- t_xmin: 2830
-- t_xmax: 0

-- ➌ check current transaction ID (≡ virtual timestamp)
SELECT txid_current(); -- 2836

SELECT txid_current(); -- 2837

-- ➍ update one row
UPDATE ternary AS t SET c = -1 WHERE  t.a = 982;

-- ➎ check visible contents of page 9 after update
SELECT t.ctid, t.*
FROM   ternary AS t
WHERE  t.ctid >= '(9,1)';
 
-- ➏ check row header contents after update
SELECT * FROM ShowHeap('Ternary', 9);
-- updated row has t_max: 2838
-- new row has t_min : 2838

VACUUM ternary;
SELECT * FROM ShowHeap('Ternary', 9);

 
DROP TABLE IF EXISTS ternary;
DROP TABLE IF EXISTS padded;
DROP TABLE IF EXISTS packed;
