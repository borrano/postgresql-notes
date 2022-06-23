
-----------------------------------------------------------------------
-- User-defined SQL Functions


-- Atomic return type (int)
-- Map subscript symbols to their numeric value: '₀' to 0, '₁' to 1, ...
-- (returns NULL if a non-subscript symbol is passed)
--
DROP FUNCTION IF EXISTS subscript(text);
CREATE FUNCTION subscript(s text) RETURNS int AS
$$
  SELECT subs.value
  FROM   (VALUES ('₀', 0),
                 ('₁', 1),
                 ('₂', 2),
                 ('₃', 3),
                 ('₄', 4),
                 ('₅', 5),
                 ('₆', 6),
                 ('₇', 7),
                 ('₈', 8),
                 ('₉', 9)) AS subs(sym,value)
  WHERE  subs.sym = s
$$
LANGUAGE SQL IMMUTABLE;


-- Alternative variant using array/WITH ORDINALITY
--
DROP FUNCTION IF EXISTS subscript(text);
CREATE FUNCTION subscript(s text) RETURNS int AS
$$
  SELECT subs.value::int - 1
  FROM   unnest(array['₀','₁','₂','₃','₄','₅','₆','₇','₈','₉'])
         WITH ORDINALITY AS subs(sym,value)
  WHERE  subs.sym = s
$$
LANGUAGE SQL IMMUTABLE;


-- Modify chemical formula parser (see above): returns actual atom count
--
--                                 ↓
SELECT t.match[1] AS element, subscript(t.match[2]) AS "# atoms", t.match[3] AS charge
FROM   regexp_matches('C₆H₅O₇³⁻',
                      '([A-Za-z]+)([₀₁₂₃₄₅₆₇₈₉]*)([⁰¹²³⁴⁵⁶⁷⁸⁹]+[⁺⁻])?',
                      'g')                    -- ────────────────
       AS t(match);                           -- does not match if no charge ⇒ yields NULL



-- Atomic return type (text), incurs side effect
-- Generate a unique ID of the form '‹prefix›###' and log time of generation
--
DROP TABLE IF EXISTS issue;
CREATE TABLE issue (
  id     int GENERATED ALWAYS AS IDENTITY,
  "when" timestamp);

DROP FUNCTION IF EXISTS new_ID(text);
CREATE FUNCTION new_ID(prefix text) RETURNS text AS
$$
  INSERT INTO issue(id, "when") VALUES
    (DEFAULT, 'now'::timestamp)
  RETURNING prefix || id::text
$$
LANGUAGE SQL VOLATILE;
--              ↑
--  "function" incurs a side-effect


-- Everybody is welcome as our customer, even bi-pedal dinosaurs!
--
SELECT new_ID('customer') AS customer, d.species
FROM   dinosaurs AS d
WHERE  d.legs = 2;

-- How is customer acquisition going?
TABLE issue;



-- Table-generating UDF (polymorphic): unnest a two-dimensional array
-- in column-major order:
--
CREATE OR REPLACE FUNCTION unnest2(xss anyarray)
  RETURNS SETOF anyelement AS
$$
SELECT xss[i][j]
FROM   generate_subscripts(xss,1) _(i),
       generate_subscripts(xss,2) __(j)
ORDER BY j, i  --  return elements in column-major order
$$
LANGUAGE SQL IMMUTABLE;

                    --  columns of 2D array
SELECT t.*          --      ↓   ↓   ↓
FROM   unnest2(array[array['a','b','c'],
                     array['d','e','f'],
                     array['x','y','z']])
       WITH ORDINALITY AS t(elem,pos);





