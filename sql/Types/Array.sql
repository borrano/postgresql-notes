
SELECT array[1,2,3];

SELECT '{1,2,3}'::int[] as nums;

SELECT '{2, NULL, 1}'::int[] as nums;

-- length
SELECT array_length(x.column1, 1) 
FROM (VALUES (array[1,2,3])) as x;

-- array position -> index of first occurence
-- array positioncs -> all occurences returned as integer[]
SELECT cardinality(x.column1), array_positions(x.column1, 2), array_position(x.column1, 2)
FROM (VALUES (array[1,2,3])) as x;

-- multi dimensional arrays
SELECT array_length(x.column1, 1) , array_length(x.column1, 2) 
FROM (VALUES (array[array[1,2,3], array[3,4, 7]])) as x; -- all inner arrays must have same length

-- indexing is 1 based
SELECT column1[2]
FROM (VALUES (array[1,2,3])) as x;

SELECT string_to_array('1;2;3;4', ';')::int[];

DROP TABLE IF EXISTS arrays;
CREATE TABLE arrays(id int, a integer[]);

INSERT INTO arrays(id, a) 
VALUES
  ( 1, array[NULL,1,2,2,1,5]),
  ( 2, array[4,1,1,6,4,NULL,6]),
  ( 3, array[NULL,1,NULL,1,3]);



--------------------------
--- ANY ALL
Note: The operator must be a standard comparison operator (=, <>, !=, >, >=, <, or <=).

-- is any element is 6
SELECT * FROM arrays 
WHERE 6 = ANY(a);

SELECT 6 = ANY(a) FROM arrays;


-- last elem 
SELECT i[cardinality(i)]
FROM (VALUES (array[1,2,3])) as x(i);

--- set returning functions can be used in select
SELECT generate_series(1,10,1) FROM arrays;

SELECT v, o  FROM arrays, unnest(a) WITH ORDINALITY as x(v, o);

-- maximum element

SELECT ar.id, MAX(val) as maxelem
FROM arrays as ar, unnest(a) WITH ORDINALITY as x(val, ind)
GROUP BY ar.id;

-- add all elements 1
SELECT ar.id, array_agg((val + 1) ORDER BY ind ASC)
FROM arrays as ar, unnest(a) WITH ORDINALITY as x(val, ind)
GROUP BY ar.id
 
---------------------------------------------
---- Representing trees using arrays 

-- Represent labelled forests using arrays:
-- - if parents[i] = j, then j is parent node of node i,
-- - if labels[i] = ℓ, then ℓ is the label of node i.


--      t₁                  t₂                     t₃
--
--   ¹     ᵃ           ⁶     ᵍ           ¹ ³     ᵃ ╷ᵈ
-- ² ⁵  ᵇ ᶜ        ⁴ ⁷  ᵇ ᶜ                  ╵
--      ╵        ¹ ⁵  ᵈ ᵉ          ² ⁴ ⁵     ᵇ ᶜ ᵉ
-- ³ ⁴⁶   ᵈ ᵉᶠ              
--                    ² ³    ᶠ ᵃ

DROP TABLE IF EXISTS Trees;
CREATE TABLE Trees (tree int PRIMARY KEY, parents int[], labels  text[]);
INSERT INTO Trees(tree, parents, labels) VALUES
  (1, array[NULL,1,2,2,1,5],   array['a','b','d','e','c','f']),
  (2, array[4,1,1,6,4,NULL,6], array['d','f','a','b','e','g','c']),
  (3, array[NULL,1,NULL,1,3],  string_to_array('a;b;d;c;e',';'));


-- Consistency: length of parents[] and labels[] match for all trees?
--
SELECT bool_and(cardinality(t.parents) = cardinality(t.labels))
FROM   Trees AS t;


-- Which trees (and nodes) carry an 'f' label?
--
SELECT t.tree, array_positions(t.labels, 'f') AS "f nodes"
FROM   Trees AS t
WHERE  'f' = ANY(t.labels);


-- Find the label of the (first) root
--
SELECT t.tree, t.labels[array_position(t.parents,NULL)] AS root
FROM   Trees AS t;


-- Which trees actually are forests (collection of trees with more
-- than one root)?
--
SELECT t.tree AS forest
FROM   Trees AS t
WHERE  cardinality(array_positions(t.parents,NULL)) > 1;



-----------------------------------------------------------------------
-- The following should be simple but are hard (impossible?) to
-- formulate:

-- ➊ Find the largest label.  Transform all labels to uppercase.
--   Find the parents of all nodes with label 'c'.
--   (Need to access all/iterate over array elements)

-- ➋ Concatenate two trees (leaf ℓ of t₁ is new parent of root of t₂)
--   (Need to adapt/shift elements in parents[], then form new array)

-- (↯☠☹⛈)

-- So many array functions, so little can be done.
-- SOMETHING'S MISSING...


-----------------------------------------------------------------------
-- unnest / array_agg

SELECT t.*
FROM   unnest(array['x₁','x₂','x₃']) WITH ORDINALITY AS t(elem,idx);

--                                   try: DESC
--                                      ↓
SELECT array_agg(t.elem ORDER BY t.idx ASC) AS xs
FROM   (VALUES ('x₁',1), ('x₂',2), ('x₃',3)) AS t(elem,idx);



-- unnest() indeed is a n-ary function that unnest multiple
-- arrays at once: unnest(xs₁,...,xsₙ), one per column.  Shorter
-- columns are padded with NULL (see zipping in table-functions.sql):
--

-- zip arrays
SELECT node.parent, node.label
FROM   Trees AS t,
       unnest(t.parents, t.labels) AS node(parent,label)
WHERE  t.tree = 2;


SELECT node.*
FROM   Trees AS t,
       unnest(t.parents, t.labels) WITH ORDINALITY AS node(parent,label,idx)
WHERE  t.tree = 2;


-- Transform all labels to uppercase:
--
SELECT t.tree,
       array_agg(node.parent ORDER BY node.idx) AS parents,
       array_agg(upper(node.label) ORDER BY node.idx) AS labels
FROM   Trees AS t,
       unnest(t.parents,t.labels) WITH ORDINALITY AS node(parent,label,idx)
GROUP BY t.tree;


-- Find the parents of all nodes with label 'c'
--
SELECT t.tree, t.parents[node.idx] AS "parent of c"
FROM   Trees AS t,
       unnest(t.labels) WITH ORDINALITY AS node(label,idx)
WHERE  node.label = 'c';


-- Find the forests among the trees:
--
SELECT t.*
FROM   Trees AS t,
       unnest(t.parents) AS node(parent)
WHERE  node.parent IS NULL
GROUP BY t.tree
HAVING COUNT(*) > 1; -- true forests have more than one root node


-- Problem ➋ (attach tree t₂ to leaf 6/f of t₁).  Yes, this is getting
-- ugly and awkward.  Arrays are helpful, but SQL is not an array
-- programming language.
--
-- Plan: append nodes of t₁ to those of t₂:
--
-- 1. Determine root r and size s (= node count) of t₂
-- 2. Shift all parents of t₁ by s, preserve labels
-- 3. Concatenate the parents of t₂ and t₁, set the parent of t2's root to leaf ℓ (shifted by s),
--    concatenate the labels of t₂ and t₁


SELECT t1.labels || t2.labels as labels, 
    t1.parents || 
    (SELECT array_agg(
            COALESCE(x + cardinality(t1.parents), 6 )
            ) FROM unnest(t2.parents) as x)
FROM Trees as t1, Trees as t2 
WHERE t2.tree = 2 AND t1.tree = 1;

 

\set t1 1
\set ℓ 6
\set t2 2

WITH
-- 1. Determine root r and size s (= node count) of t2
t2(root,size,parents,labels) AS (
  SELECT array_position(t2.parents,NULL) AS root,
         cardinality(t2.parents) AS size,
         t2.parents,
         t2.labels
  FROM   Trees AS t2
  WHERE  t2.tree = :t2
),
-- 2. Shift all parents of t1 by s, preserve labels
t1(parents,labels) AS (
  SELECT (SELECT array_agg(node.parent + t2.size ORDER BY node.idx)
          FROM   unnest(t1.parents) WITH ORDINALITY AS node(parent,idx)) AS parents,
         t1.labels
  FROM   Trees AS t1, t2
  WHERE  t1.tree = :t1
)
-- 3. Concatenate the parents of t2 and t1, set the parent of t2's root to leaf ℓ (shifted by s),
--    concatenate the labels of t2 and t1
SELECT (SELECT array_agg(CASE node.idx WHEN t2.root THEN :ℓ + t2.size
                                       ELSE node.parent
                         END
                         ORDER BY node.idx)
        FROM   unnest(t2.parents) WITH ORDINALITY AS node(parent,idx)) || t1.parents AS parents,
       t2.labels || t1.labels AS labels
FROM   t1, t2;

 

---------------------------
--- indexes on arrays

DROP TABLE IF EXISTS arrays;

CREATE TABLE arrays (id serial, xs int[]);
 
INSERT INTO arrays(xs) 
SELECT   array_agg(j) FROM 
generate_series (1, 100000, 1) as i,  generate_series((i - 1), (i - 1) + 500, 1) as j
GROUP BY i;
 
CREATE INDEX arrays_xs ON arrays using gin(xs);
ANALYZE arrays;

EXPLAIN ANALYZE
SELECT * FROM 
arrays as a
WHERE    a.xs  @> '{601}' ;