-------------------------------
----- Transaction ID wraparound
-- The implementation of MVCC in PostgreSQL uses a transaction ID that is 32 bits in size. 
-- Why not 64 bits: visibility information is stored every row huge overhead.


DROP TABLE IF EXISTS unary;
CREATE TABLE unary(a int);
INSERT INTO unary(a) SELECT * FROM generate_series(1,100, 1);

VACUUM unary;

SELECT relname,relfrozenxid, age(relfrozenxid) 
FROM pg_class 
WHERE relkind='r'
ORDER BY age(relfrozenxid) DESC;

-- frozen for the table
-- unary	3206	4
SELECT relname,relfrozenxid, age(relfrozenxid) 
FROM pg_class 
WHERE relname='unary' 
ORDER BY age(relfrozenxid) DESC;

-- test	726	2484
SELECT datname, datfrozenxid, age(datfrozenxid) 
FROM pg_database 
WHERE datname = 'test'
ORDER BY age(datfrozenxid) DESC;

SELECT txid_current();

SELECT t_xmin, t_xmax, combined_flags, raw_flags FROM ShowHeap('unary', 0); 
-- HEAP_XMIN_COMMITTED -> frozen tuple 
-- if HEAP_XMIN_COMMITTED then tuple is in the past

-- long running transactions interferes with freezing

VACUUM freeze  ;
VACUUM full  ;

-- age is 0 now
SELECT relname,relfrozenxid, age(relfrozenxid) 
FROM pg_class 
WHERE relname='unary' 
ORDER BY age(relfrozenxid) DESC;


-- if you are not regularly freezing tuples in tables - database is shutdown 
-- autovacuum freezes tuples

parameters:
vacuum_freeze_min_age
vacuum_freeze_table_age
autovacuum_freeze_max_age

--This maintenance is also critical to cleaning up the commit log information.
-- visibility map is used in vacuum