-----------------------------------------------------------------------
DROP TABLE IF EXISTS T;
CREATE TABLE T (a int PRIMARY KEY, b text, c boolean, d int);

INSERT INTO T VALUES
  (1, 'x',  true, 10),
  (2, 'y',  true, 40),
  (3, 'x', false, 30),
  (4, 'y', false, 20),
  (5, 'x',  true, NULL);

SELECT t.* FROM T AS t
TABLE T;

-- JSON

-- jsonb
VALUES (1, '{ "b":1, "a":2 }'       ::jsonb),  -- ← pair order may flip
       (2, '{ "a":1, "b":2, "a":3 }'       ),  -- ← duplicate field
       (3, '[ 0,   false,null ]'           );  -- ← whitespace normalized

-- json
VALUES (1, '{ "b":1, "a":2 }'       ::json ),  -- ← pair order and ...
       (2, '{ "a":1, "b":2, "a":3 }'       ),  -- ← ... duplicates preserved
       (3, '[ 0,   false,null ]'           );  -- ← whitespace preserved


SELECT ('{ "b":1, "a":2 }'       ::jsonb )-> 'b';  -- extract as jsonb
SELECT ('{ "b":1, "a":2 }'       ::jsonb )->> 'b';  -- extract as text


-- Navigating in an extracting from a JSON value
SELECT ('{ "a":0, "b": { "b1":1, "b2":2 } }' :: jsonb -> 'b' ->> 'b2')::int + 40;
--                                                            ↑
--                                       extract as text (cannot cast jsonb to τ)


-------------------------------
-- Goal: Convert table into JSON (jsonb) array of objects

-- Step ➊: convert each row into a JSON object (columns ≡ fields)
--
SELECT row_to_json(t)::jsonb
FROM   T AS t;

-- Step ➋: aggregate the table of JSON objects into one JSON array
--          (here: in some element order)
--
--  may understood as a unity for now (array_agg() in focus soon)
--     ╭──────────┴───────────╮
SELECT array_to_json(array_agg(row_to_json(t)))::jsonb
FROM   T as t;


-- Pretty-print JSON output
--
SELECT jsonb_pretty(array_to_json(array_agg(row_to_json(t)))::jsonb)
FROM   T as t;


-- Table T represented as a JSON object (JSON value in single row/single column)
DROP TABLE IF EXISTS T2;

CREATE TABLE T2(a jsonb);
INSERT INTO T2(a) 
  SELECT array_to_json(array_agg(row_to_json(t)))::jsonb
  FROM   T as t;

TABLE T2;

-------------------------------
-- Goal: Convert JSON object (array of regular objects) into a table:
--       can we do a round-trip and get back the original T?


-- Step ➊: convert array into table of JSON objects
--
SELECT objs.o
FROM   jsonb_array_elements((TABLE T2)) AS objs(o);

-- NB: Steps ➋a and ➋b/c lead to alternative tabular representation:

-- Step ➋a: turn JSON objects into key/value pairs (⚠ column value::jsonb)
--
SELECT t.*
FROM   jsonb_array_elements((TABLE T2)) AS objs(o),
       jsonb_each(o) AS t;


-- Step ➋b: turn JSON objects into rows (fields ≡ columns)
--
SELECT t.*
FROM   jsonb_array_elements((TABLE T2)) AS objs(o),
       jsonb_to_record(o) AS t(a int, b text, c boolean, d int);
--                           ╰────────────────┬───────────────╯
--                   explicitly provide column name and type information
--                      (⚠ column and field names/types must match)

SELECT t.*
FROM   jsonb_array_elements((TABLE T2)) AS objs(o),
       jsonb_to_record(o) AS t(a int, b text, c boolean );

-- Step ➋c: turn JSON objects into rows (fields ≡ columns)
--
SELECT t.*
FROM   jsonb_array_elements((TABLE T2)) AS objs(o),
       jsonb_populate_record(NULL :: T, o) AS t;
--                          ╰───┬────╯
--   derive column names and types from T's row type (cf. Chapter 02)
--            (⚠ column and field names/types must match)



-- Steps ➊+➋: from array of JSON objects directly to typed tables
SELECT t.*
FROM   jsonb_populate_recordset(NULL :: T, (TABLE T2)) AS t;



SELECT '{"a":12}'::jsonb || '{"b":13}' ;
