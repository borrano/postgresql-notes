DROP TABLE IF EXISTS ternary;

CREATE TABLE ternary (a int NOT NULL, b text NOT NULL, c numeric(3,2));

INSERT INTO ternary(a, b, c)
SELECT i AS a, md5(i::text) AS b, sin(i) AS c
FROM generate_series(1, 1000000, 1) AS i;
 