DROP TABLE IF EXISTS ternary;

CREATE TABLE ternary (a int NOT NULL, b text NOT NULL, c numeric(3,2));

INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b, sin(i) AS c
FROM generate_series(1, 1000000, 1) AS i;

CREATE INDEX ternary_a ON ternary USING btree(a);

---------------------------------


-- The index is an additional data structure, maintained by the DBMS.
-- Lives persistently in extra heap file.
SELECT relname, relfilenode, relpages, reltuples, relkind
FROM   pg_class
WHERE  relname LIKE 'ternary%';
-- relname: 	ternary_a	
-- oid: 19376
-- relpages: 	2745	
-- reltuples: 1000000	
-- relkind: i

EXPLAIN (ANALYZE, VERBOSE, BUFFERS)
SELECT * FROM ternary WHERE a = 42;

--Index Scan using ternary_a on public.ternary  
--  (cost=0.29..8.30 rows=1 width=45) (actual time=0.007..0.007 rows=1 loops=1)
--  Output: a, b, c
--  Index Cond: (ternary.a = 42)
-- Execution Time: 0.025 ms
-- Buffers: shared hit=4

set enable_indexscan = off;
set enable_bitmapscan = off;

-- Reevaluate Q8 without index support
EXPLAIN (VERBOSE, ANALYZE, BUFFERS)
  SELECT i.b, i.c
  FROM   ternary AS i
  WHERE  i.a = 42;

--Execution Time: 19.082 ms
-- Buffers: shared hit=9346


-- Re-enable index support
set enable_indexscan = on;
set enable_bitmapscan = on;

---------------------------------
-- BTREE page file structure
-- LEAF NODES

CREATE EXTENSION IF NOT EXISTS pageinspect;

SELECT node.*
FROM   generate_series(1, 2744) AS p,
       LATERAL bt_page_stats('ternary_a', p) AS node
WHERE  node.type = 'l'  -- l ≡ leaf, i ≡ inner, r ≡ root
ORDER BY node.blkno LIMIT 3;

-- avg_item_size : each key cid pairs 16 bytes
-- btpo_prev - btpo_next
-- btpo_level - level of the bplus tree
-- dead_items:? 
-- btpo_flags:?
-- free size : there are some free space left to avoid insertion overhead 


-- Recursively walk the sequence set chain and extract the
-- number of index entries found in each leaf (subtract 1
-- from live_items for all pages but the rightmost page)
WITH RECURSIVE sequence_set(leaf, next, entries) AS (
  -- Find first (leftmost) node in sequence set
  SELECT node.blkno          AS leaf,
         node.btpo_next      AS next,
         node.live_items - (node.btpo_next <> 0)::int AS entries  -- node.btpo_next <> 0 ≡ node is not rightmost on tree level
  FROM   pg_class AS c,
         LATERAL generate_series(1, c.relpages-1) AS p,
         LATERAL bt_page_stats('ternary_a', p) AS node
  WHERE  c.relname = 'ternary_a' AND c.relkind = 'i'
  AND    node.type = 'l' AND node.btpo_prev = 0
   UNION ALL
  -- Find next (if any) node in sequence set
  SELECT node.blkno          AS leaf,
         node.btpo_next      AS next,
         node.live_items - (node.btpo_next <> 0)::int AS entries
  FROM   sequence_set AS s,
         LATERAL bt_page_stats('ternary_a', s.next) AS node
  WHERE  s.next <> 0
)
-- TABLE sequence_set;
SELECT SUM(s.entries) AS entries
FROM   sequence_set AS s;



-- Now focus on the leaf entries on page #1 of indexed_a:

-- Access leaf entries on page #1 (a leaf page, see above) of indexed_a:
SELECT *
FROM   bt_page_items('ternary_a', 1);

-- itemoffset |  ctid   | itemlen | nulls | vars |          data           | dead |  htid   | tids 
-- ------------+---------+---------+-------+------+-------------------------+------+---------+------
--           1 | (3,1)   |      16 | f     | f    | 6f 01 00 00 00 00 00 00 |      |         | 
--           2 | (0,1)   |      16 | f     | f    | 01 00 00 00 00 00 00 00 | f    | (0,1)   | 
-- leftmost entry is highest value of the next page - points to 
-- ctid - points to
-- htid ?


---------------------------------
-- BTREE page file structure
-- Inner NODES

SELECT root, level
FROM   bt_metap('ternary_a');

-- root | level 
-- ------+-------
--   290 |     2

SELECT *
FROM   bt_page_stats('ternary_a', 290);

-- blkno         | 290
-- type          | r
-- live_items    | 10
-- dead_items    | 0
-- avg_item_size | 15
-- page_size     | 8192
-- free_size     | 7956
-- btpo_prev     | 0
-- btpo_next     | 0
-- btpo_level    | 2
-- btpo_flags    | 2

SELECT itemoffset, itemlen, ctid, data
FROM   bt_page_items('ternary_a', 290)
ORDER BY itemoffset;

-- -[ RECORD 1 ]-----------------------
-- itemoffset | 1
-- itemlen    | 8
-- ctid       | (3,0)
-- data       | 
-- -[ RECORD 2 ]-----------------------
-- itemoffset | 2
-- itemlen    | 16
-- ctid       | (289,1)
-- data       | 09 96 01 00 00 00 00 00

SELECT itemoffset, itemlen, ctid, data
FROM   bt_page_items('ternary_a', 3)
ORDER BY itemoffset;

-- first next page key - next page pointer
-- second leftmost pointer
-- -[ RECORD 1 ]-----------------------
-- itemoffset | 1
-- itemlen    | 16
-- ctid       | (286,1)
-- data       | 09 96 01 00 00 00 00 00
-- -[ RECORD 2 ]-----------------------
-- itemoffset | 2
-- itemlen    | 8
-- ctid       | (1,0)
-- data       | 
-- -[ RECORD 3 ]-----------------------
-- itemoffset | 3
-- itemlen    | 16
-- ctid       | (2,1)
-- data       | 6f 01 00 00 00 00 00 00