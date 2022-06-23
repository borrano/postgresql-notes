---- postgres 13

DROP TABLE IF EXISTS unary;

CREATE TABLE unary(a text);

INSERT INTO unary 
SELECT 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' FROM generate_series(1, 5000, 1);

CREATE INDEX unary_a ON unary USING btree(a);


SELECT relpages, reltuples FROM pg_class WHERE relname = 'unary_a'; -- only 7 page

------------------------------------

DROP TABLE IF EXISTS unary;

CREATE TABLE unary(a text);

INSERT INTO unary 
SELECT md5(i::text) FROM generate_series(1, 5000, 1) as i;

CREATE INDEX unary_a ON unary USING btree(a);
 
SELECT relpages, reltuples FROM pg_class WHERE relname = 'unary_a'; -- only 7 page
--38 pages