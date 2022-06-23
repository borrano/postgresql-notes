-----------------------------------------------------------------------
-- Sequences

-- ⚠ Sequences and table share a common name space, watch out for
--   collisions
DROP SEQUENCE IF EXISTS seq;
CREATE SEQUENCE seq START 41 MAXVALUE 100 CYCLE;
TABLE seq; --is_called false

SELECT nextval('seq');      -- ⇒ 41
SELECT nextval('seq');      -- ⇒ 42
SELECT currval('seq');      -- ⇒ 42
SELECT setval ('seq',100);  -- ⇒ 100 (+ side effect)
SELECT nextval('seq');      -- ⇒ 1   (wrap-around)

-- Sequences are system-maintained single-row/single-column tables:
--
TABLE seq; -- log_cnt -> 32

-- ┌───────────────┬─┈┈─┬───────────┐
-- │ sequence_name │    │ is_called │
-- ├───────────────┼─┈┈─┼───────────┤
-- │ seq           │    │ t         │ ← has nextval() been called already?
-- └───────────────┴─┈┈─┴───────────┘

--                     is_called
--                         ↓
SELECT setval ('seq',100,false);  -- ⇒ 100 (+ side effect)
SELECT nextval('seq');            -- ⇒ 100


DROP TABLE IF EXISTS self_concious_T;
CREATE TABLE self_concious_T (me serial,
                               a int PRIMARY KEY,
                               b text,
                               c boolean,
                               d int);


INSERT INTO self_concious_T(me,a,b,c,d) VALUES
  (DEFAULT,  1, 'x',  true, 10);

INSERT INTO self_concious_T(me,a,b,c,d) VALUES
  (DEFAULT,  2, 'y',  true, 40);

--                    column me missing (⇒ receives DEFAULT value)
--                         ╭───┴───╮
INSERT INTO self_concious_T(a,b,c,d) 
VALUES
  (5, 'x', true,  NULL),
  (4, 'y', false, 20),
  (3, 'x', false, 30)
  RETURNING me, c;
--            ↑
--     General INSERT feature:
--     Any list of expressions involving the column name of
--     the inserted rows (or * to return entire inserted rows)
--     ⇒ User-defined SQL functions (UDFs)
DROP TABLE IF EXISTS prods;
DROP TABLE IF EXISTS prods_prices;

CREATE TABLE prods(id int, price int);
CREATE TABLE prods_prices(prod_id int, price int);

INSERT INTO prods(id, price) VALUES(1, 2), (3, 4), (2, 1);
INSERT INTO prods_prices( prod_id, price) VALUES(1, 2), (1, 5), (2, 0), (2, 3), (2, -1);



SELECT DISTINCT ON (p.id) p.id, 
  (CASE WHEN pp.price IS NULL THEN p.price ELSE pp.price END) 
FROM prods as p 
LEFT JOIN prods_prices as pp
ON p.id = pp.prod_id
ORDER BY p.id, pp.price;