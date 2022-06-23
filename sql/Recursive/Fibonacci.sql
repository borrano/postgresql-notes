DROP FUNCTION IF EXISTS generate_series2(int, int);
CREATE FUNCTION generate_series2("from" int, "to" int) RETURNS TABLE(i int) AS
$$
  WITH RECURSIVE temp(a  ) as (
        SELECT "from"
        UNION 
        SELECT a + 1 FROM temp WHERE a < "to"
  )
  SELECT * FROM temp;
$$
LANGUAGE SQL IMMUTABLE;


DROP FUNCTION IF EXISTS fib(int);
CREATE FUNCTION fib("n" int) RETURNS TABLE(i int) AS
$$
    WITH RECURSIVE FIB(n, a, b ) as (
        SELECT 0, 0, 1 
        UNION  
        SELECT f.n + 1, f.b, f.a + f.b FROM FIB as f WHERE f.n < "n"
    )
    SELECT f.a FROM FIB as f LIMIT 10;
$$
LANGUAGE SQL IMMUTABLE;

SELECT fib(12);






WITH RECURSIVE FAC(n, r) as (
    SELECT 1, 1
    UNION
    SELECT f.n + 1, (f.n + 1) * f.r FROM FAC as f WHERE f.n < 4
)
SELECT r FROM FAC ;


-- UNION OR UNION ALL 

SELECT * FROM generate_series2(1,10);
