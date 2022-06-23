SELECT datname, oid FROM pg_database;
SELECT relname, oid FROM pg_class;

show data_directory;
-- /var/lib/postgresql/14/main

DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (a int NOT NULL, b text NOT NULL, c float);
INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b, log(i) AS c
FROM generate_series(1, 1000, 1) AS i;

-- tid scan
EXPLAIN ANALYZE
SELECT ctid  FROM ternary WHERE ctid = '(0,1)';
