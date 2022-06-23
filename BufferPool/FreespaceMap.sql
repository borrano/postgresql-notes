CREATE EXTENSION IF NOT EXISTS pg_freespacemap;

DROP TABLE IF EXISTS unary;

CREATE TABLE unary (a int);

INSERT INTO unary(a) SELECT i FROM generate_series(1, 1000, 1) AS i;

VACUUM unary;
SELECT * FROM pg_freespace('unary');

DELETE FROM unary AS u WHERE u.a BETWEEN 400 AND 500;
INSERT INTO unary(a) VALUES(-1);
SELECT ctid, * FROM unary WHERE a = -1;

VACUUM unary;
INSERT INTO unary(a) VALUES(-1);
SELECT ctid, * FROM unary WHERE a = -1;

SELECT * FROM pg_freespace('unary');

-- tree shaped fsm
-- free spaces represented with 32 byte granularity. 
-- 2^13 / 2^5 -> single byte is enough