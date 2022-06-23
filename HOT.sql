DROP FUNCTION IF EXISTS ShowHeap;
CREATE FUNCTION ShowHeap( ) RETURNS TABLE(lp text, raw_flags text, lp_off text, lp_flags text, lp_len text, t_xmin text, t_xmax text, t_field3 text, t_ctid text, t_hoff text, t_bits text, t_oid text) 
    AS $$    
      SELECT lp, raw_flags, lp_off, lp_flags, lp_len, t_xmin, t_xmax, t_field3,t_ctid, t_hoff, t_bits, t_oid 
FROM heap_page_items(get_raw_page('T', 0)), LATERAL heap_tuple_infomask_flags(t_infomask, t_infomask2)
WHERE t_infomask IS NOT NULL OR t_infomask2 IS NOT NULL; 
    $$
    LANGUAGE SQL;
    

SELECT * FROM pg_stat_all_tables WHERE relname = 't';
SELECT n_tup_hot_upd FROM pg_stat_user_tables WHERE relname = 't';

DROP TABLE IF EXISTS T;
CREATE TABLE T (a int  ,
                b text,
                c boolean,
                d int);
CREATE INDEX a_index ON T(a);

CREATE INDEX b_index ON T(b);

INSERT INTO T VALUES
  (1, 'x',  true, 10),
  (2, 'y',  true, 40),
  (3, 'x', false, 30),
  (4, 'y', false, 20),
  (5, 'x',  true, NULL);

SELECT * FROM ShowHeap();

UPDATE T SET d = 12 WHERE a = 1; -- HOT UPDATED

SELECT * FROM   bt_page_items('b_index', 1) LIMIT 10; -- index did not change
SELECT * FROM   bt_page_items('a_index', 1) LIMIT 10; -- index did not change
SELECT * FROM ShowHeap();  -- Heap Only Tuple

UPDATE T SET b = 'b' WHERE a = 1; -- NOT HOT UPDATED if any indexed column changes not a hot update

SELECT * FROM   bt_page_items('b_index', 1) LIMIT 10; -- added to index
SELECT * FROM   bt_page_items('a_index', 1) LIMIT 10; -- added to index
-- indexes don't contain visibility information in postgres
SELECT * FROM ShowHeap(); 



ALTER TABLE T SET (fillfactor = 10);

UPDATE T SET d = 12;   -- HOT UPDATED
UPDATE T SET d = 12;   -- HOT UPDATED
UPDATE T SET d = 12;   -- HOT UPDATED
UPDATE T SET d = 12;   -- HOT UPDATED
--
UPDATE T SET d = 12;   -- PRUNED
SELECT * FROM ShowHeap(); 

-- add different fill factor benchmarks


--- VACUUM

DROP TABLE IF EXISTS T;
CREATE TABLE T (a int  ,
                b text,
                c boolean,
                d int);
CREATE INDEX a_index ON T(a);

CREATE INDEX b_index ON T(b);

INSERT INTO T VALUES
  (1, 'x',  true, 10),
  (2, 'y',  true, 40),
  (3, 'x', false, 30),
  (4, 'y', false, 20),
  (5, 'x',  true, NULL);

UPDATE T SET b = 'b' WHERE a = 1; -- NOT HOT UPDATED if any indexed column changes not a hot update
UPDATE T SET b = 'b' WHERE a = 1; -- NOT HOT UPDATED if any indexed column changes not a hot update


VACUUM VERBOSE T;
-- INFO:  vacuuming "public.t"
-- INFO:  scanned index "a_index" to remove 1 row versions
-- DETAIL:  CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
-- INFO:  scanned index "b_index" to remove 1 row versions
-- DETAIL:  CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
-- INFO:  table "t": removed 1 dead item identifiers in 1 pages
-- DETAIL:  CPU: user: 0.00 s, system: 0.00 s, elapsed: 0.00 s
-- INFO:  index "a_index" now contains 5 row versions in 2 pages

 
