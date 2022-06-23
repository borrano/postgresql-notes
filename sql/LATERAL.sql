
-----------------------------------------------------------------------
-- Dependent iteration (LATERAL)

-- Exception: dependent iteration OK in table-generating functions
--
SELECT t.tree, MAX(node.label) AS "largest label"
FROM   Trees AS t,
       LATERAL unnest(t.labels) AS node(label)  -- ⚠ refers to t.labels: dependent iteration
GROUP BY t.tree;


-- Equivalent reformulation (dependent iteration → subquery in SELECT)
--
SELECT t.tree, (SELECT MAX(node.label)
                FROM   unnest(t.labels) AS node(label)) AS "largest label"
FROM   Trees AS t
GROUP BY t.tree;


-- ⚠ This reformulation is only possible if the subquery yields
--   a scalar result (one row, one column) only ⇒ LATERAL is more general.
--   See the example (and its somewhat awkward reformulation) below.



-- Find the three tallest two- or four-legged dinosaurs:
--
SELECT locomotion.legs, tallest.species, tallest.height
FROM   (VALUES (2), (4)) AS locomotion(legs),
       LATERAL (SELECT d.*
                FROM   dinosaurs AS d
                WHERE  d.legs = locomotion.legs
                ORDER BY d.height DESC
                LIMIT 3) AS tallest;


-- Equivalent reformulation without LATERAL
--
WITH ranked_dinosaurs(species, legs, height, rank) AS (
  SELECT d1.species, d1.legs, d1.height,
         (SELECT COUNT(*)                          -- number of
          FROM   dinosaurs AS d2                   -- dinosaurs d2
          WHERE  d1.legs = d2.legs                 -- in d1's peer group
          AND    d1.height <= d2.height) AS rank   -- that are as large or larger as d1
  FROM   dinosaurs AS d1
  WHERE  d1.legs IS NOT NULL
)
SELECT d.legs, d.species, d.height
FROM   ranked_dinosaurs AS d
WHERE  d.legs IN (2,4)
AND    d.rank <= 3
ORDER BY d.legs, d.rank;

