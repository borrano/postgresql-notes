--- after psql13

DROP TABLE IF EXISTS bin;

CREATE TABLE bin(a int, b int);

INSERT INTO bin 
SELECT i, i FROM generate_series(1, 1000000, 1) as i;

CREATE INDEX bin_a ON bin USING btree(a);

VACUUM FREEZE bin;


EXPLAIN (ANALYZE, VERBOSE, BUFFERS) 
 
SELECT * FROM bin ORDER BY a;


--Incremental Sort  (cost=0.47..75408.43 rows=1000000 width=8) (actual time=0.029..152.418 rows=1000000 loops=1)
--  Output: a, b
--  Sort Key: bin.a, bin.b
--  Presorted Key: bin.a
--  Full-sort Groups: 31250  Sort Method: quicksort  Average Memory: 26kB  Peak Memory: 26kB
--  Buffers: shared hit=7167
--  ->  Index Scan using bin_a on public.bin  (cost=0.42..30408.42 rows=1000000 width=8) (actual time=0.008..71.275 rows=1000000 loops=1)
--        Output: a, b
--        Buffers: shared hit=7160
--Execution Time: 176.801 ms

EXPLAIN (ANALYZE, VERBOSE, BUFFERS) 
SELECT * FROM bin ORDER BY a, b;

set enable_incremental_sort = 'off';
set work_mem = '64MB';
EXPLAIN (ANALYZE, VERBOSE, BUFFERS) 
SELECT * FROM bin ORDER BY a, b;
