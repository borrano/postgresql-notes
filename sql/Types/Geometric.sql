-- Geometric objects


-- Estimate the value of π using the "Monte Carlo method":
--
-- ➊ Place circle c with r = 0.5 at point (0.5, 0.5).
--   Area of c is πr² = π/4.
-- ➋ Generate random point p in unit square (0,0)-(1,1).
--   Area of square is 1.
-- ⇒ Chance of p being in c = (π/4)/1 = π/4.
--
--               π/4 = nᵢₙ/n


 
SELECT (COUNT(*)::float / 100000) * 4 AS π
FROM   generate_series(1, 100000) AS _
WHERE  circle(point(0.5,0.5), 0.5) @> point(random(),random());

SELECT point(1,2);
SELECT box(point(1,2), point(3, 4));
SELECT '[(1,2), (3, 4)]'::path;
SELECT '((1,2), (3, 4), (5,6))'::polygon;
SELECT '<(1,2), 5>'::circle;
SELECT circle(point(0.5,0.5), 0.5);

SELECT point(1,2) * 4;

-- Scan RESOLUTION in x/y dimension
\set RESOLUTION 0.01
-- Shape id to scan
\set SHAPE 3
-- CSV output file (⚠ adjust this path to fit your file system)
\set CSV '/tmp/contour.csv'

-- Output scan result into CSV file (⟨x⟩,⟨bottom⟩,⟨top⟩),
-- run Gnuplot script 'scanner.gpl' to render output as SVG
COPY (

  WITH
  -- A table of shapes (polygons)
  shapes(id, shape) AS (
    VALUES (1, '((0,0), (1,1.5), (2,0))'::polygon),              -- △
           (2, polygon(box(point(0.5,0.5) , point(1.2, 3.0)))),  -- □
           (3, polygon(circle(point(0,0), 1))),                  -- ○ (12 points)
           (4, '((0,1), (2,2), (0,3), (2,4),
                 (3,2), (5,1), (3,0))'::polygon)                 -- ⭔ (complex)
  ),
  -- Determine center, width, and height of box around shape s
  -- ⚠ The repeated computation of box(s.shape) calls for use of LATERAL
  --    (see replacement query for bboxes below)
  boxes(id, center, w, h) AS (
    SELECT s.id,
           center(box(s.shape))  AS center,
           width(box(s.shape))   AS width,
           height(box(s.shape))  AS height
    FROM   shapes AS s
  ),
  -- Perform horizontal scan of all shapes:
  -- 1. The bounding boxes provide scan ranges in x/y dimensions
  -- 2. Test whether point (x,y) lies in shape
  -- 3. Record minimum (bottom) and maximum (top) y value for each x
  trace(id, x, bottom, top) AS (
    SELECT  s.id, x, MIN(y) AS bottom, MAX(y) AS top
    FROM    shapes AS s, boxes AS b,
            generate_series((b.center[0] - b.w / 2) :: numeric, (b.center[0] + b.w / 2) :: numeric, :RESOLUTION) AS x,
            generate_series((b.center[1] - b.h / 2) :: numeric, (b.center[1] + b.h / 2) :: numeric, :RESOLUTION) AS y
    WHERE   s.id = b.id
    AND     point(x,y) <@ s.shape
    GROUP BY s.id, x
    ORDER BY s.id, x
  )
  SELECT t.x, t.bottom, t.top
  FROM   trace AS t
  WHERE  t.id = :SHAPE

) TO :'CSV' WITH (FORMAT csv);