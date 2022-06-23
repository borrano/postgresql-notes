DROP TABLE IF EXISTS ternary;
CREATE TABLE ternary (
  a int PRIMARY KEY,
  b text,
  c numeric(3,2));
 
INSERT INTO ternary(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(1,1000000) AS i;

--- create single table view
CREATE OR REPLACE VIEW ternary_view AS
SELECT a, b, c FROM ternary WHERE c = 0.84;

SELECT * FROM ternary_view LIMIT 100;

-- if view is from single table underlying table can be updated
UPDATE ternary_view SET a = -1 WHERE  a = 1;

SELECT * FROM ternary_view ORDER BY a LIMIT 1;

-- the result is not part of the view (c is changed)
UPDATE ternary_view SET c = 0.85 WHERE  a = -1;

SELECT * FROM ternary_view ORDER BY a LIMIT 1;

-- to disallow it use   WITH CHECK OPTION;

TRUNCATE ternary;
INSERT INTO ternary(a,b,c)
  SELECT i, md5(i::text), sin(i)
  FROM   generate_series(1,1000000) AS i;

CREATE OR REPLACE VIEW ternary_view AS
SELECT a, b, c FROM ternary WHERE c = 0.84 WITH CHECK OPTION;

--ERROR: new row violates check option for view "ternary_view"
UPDATE ternary_view SET c = 0.85 WHERE  a = 1;
