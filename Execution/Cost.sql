DROP TABLE IF EXISTS tbl;
CREATE TABLE tbl (id int PRIMARY KEY, data int);

CREATE INDEX tbl_data_idx ON tbl (data);
INSERT INTO tbl SELECT generate_series(1,10000),generate_series(1,10000);
ANALYZE;


------------------------------------------------------
--- Estimation of sequential scan 
--q1
EXPLAIN
SELECT * FROM tbl;
-- Seq Scan on tbl  (cost=0.00..145.00 rows=10000 width=8)

--q2
EXPLAIN
SELECT * FROM tbl WHERE id < 8000;
--Seq Scan on tbl  (cost=0.00..170.00 rows=7999 width=8)
--  Filter: (id < 8000)

-- In the sequential scan, the start-up cost is equal to 0, and the run cost is defined by the following equation: 
-- run cost =‘cpu run cost’+‘disk run cost--

-- =((cpu_tuple_cost + cpu_operator_cost)× Ntuple )+(seq_page_cost × Npage)


SELECT s.name, s.setting   FROM pg_settings as s
WHERE   s .name IN ('cpu_tuple_cost', 'cpu_operator_cost', 'seq_page_cost');

--1	cpu_operator_cost	0.0025
--2	cpu_tuple_cost	0.01
--3	seq_page_cost	1

SELECT relpages as Npage, reltuples as Ntuple, 
     ((0.01  ) * reltuples )+(1 * relpages) as q1,
     ((0.01 + 0.0025) * reltuples )+(1 * relpages) as q2
FROM pg_class as c WHERE c.relname='tbl'; 
 
-------------------------------------------------------------------------------
-- Estimation of index scan
EXPLAIN
SELECT id, data FROM tbl WHERE data < 240;
--Index Scan using tbl_data_idx on tbl  (cost=0.29..13.47 rows=239 width=8)

SELECT s.name, s.setting   FROM pg_settings as s
WHERE   s .name IN ('random_page_cost', 'cpu_index_tuple_cost'  );
--1	cpu_index_tuple_cost	0.005
--2	random_page_cost	4

-- selectivity calculated from histograms
SELECT histogram_bounds  FROM pg_stats 
WHERE tablename = 'tbl' AND attname='data';

-- correlation
SELECT tablename,attname, correlation FROM pg_stats WHERE tablename = 'tbl';

-- start-up cost’={ceil(log2(numberof_index_tuples))+(index_height+1)×50}×cpu_operator_cost
--‘run cost’=(‘index cpu cost’+‘table cpu cost’)+(‘index IO cost’+‘table IO cost’).


-- how many pages will be accessed
--index IO cost’=ceil(Selectivity×Nindex,page)×random_page_cost,
--index IO cost’=ceil(0.024 * 30 ) * 4,


--index cpu cost =Selectivity×index_tuples×(cpu_index_tuple_cost+qual_op_cost),
--table cpu cost =Selectivity×Ntuple×cpu_tuple_cost,

--table IO cost’=max_IO_cost+indexCorrelation2×(min_IO_cost−max_IO_cost).

--max_IO_cost=Npage×random_page_cost -- all pages random
--min_IO_cost=1×random_page_cost+(ceil(Selectivity×Npage)−1)×seq_page_cost.
--first one random rest of them sequential

-- On the other hand, in recent days, the default value of random_page_cost is too large because SSDs are mostly used. If the default value of random_page_cost is used despite using an SSD, the planner may select ineffective plans.
-- Therefore, when using an SSD, it is better to change the value of random_page_cost to 1.0. 
-- 

SELECT relpages as index_pages, reltuples as index_tuples, level as height,
    0.0025  *  (ceil(LOG(2.0, reltuples :: numeric))  + ((level + 1) * 50)) as startup_cost,
FROM pg_class as c, bt_metap('tbl_data_idx') as btree
WHERE c.relname='tbl_data_idx'; 
 


-------------------------------------------------------------------------------
-- Cost Estimation of in memory sorting
EXPLAIN (VERBOSE, ANALYZE)
SELECT id, data FROM tbl WHERE data < 240 ORDER BY id;

-- comparison_cost is defined in 2×cpu_operator_cost
--‘start-up cost’= comparison_cost×Nsort×log2(Nsort),
-- = 2×cpu_operator_cost * 240 * log2(240) 

-- run cost’=cpu_operator_cost×Nsort=0.0025×240=0.6.