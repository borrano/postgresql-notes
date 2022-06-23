
-----------------------------------------------------------------------
-- Efficiently paging through a table

\set rows_per_page 10

-- Set up connections table and its index
DROP TABLE IF EXISTS connections;
CREATE TABLE connections (
  id          int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  "when"      timestamp,
  destination text
);

INSERT INTO connections ("when", destination)
  SELECT now() + make_interval(mins => i) AS "when",
         md5(i :: text) AS destination
  FROM   generate_series(1, 10000) AS i;

CREATE INDEX connections_when_id
  ON connections USING btree ("when", id);
ANALYZE connections;

\d connections

TABLE connections
ORDER BY "when", id
LIMIT 10;

-- Paging implementation option ➊: Using OFFSET and LIMIT

-- Browse pages, starting from #0
\set page 0

EXPLAIN (VERBOSE, ANALYZE)
  SELECT c.*
  FROM   connections AS c
  ORDER BY c."when"
  OFFSET :page * :rows_per_page
  LIMIT  :rows_per_page;

-- Continue browsing, at page #900 (of 10 rows each) now
\set page 900

EXPLAIN (VERBOSE, ANALYZE)
  SELECT c.*
  FROM   connections AS c
  ORDER BY c."when"
  OFFSET :page * :rows_per_page
  LIMIT  :rows_per_page;




-- Paging implementation option ➋: Using WHERE and LIMIT (NO OFFSET!)

-- Initialization: first connection is where we start browsing (page #0),
-- set :last_when, :last_id to that first connection
SELECT c."when", c.id
FROM   connections AS c
ORDER BY c."when", c.id
LIMIT 1;

--  sets :last_when, :last_id
\gset last_

-- Query submitted by the Web app: produce one page of connections
EXPLAIN (VERBOSE, ANALYZE)
  SELECT c.*
  FROM   connections AS c
  WHERE  (c."when", c.id) >= (:'last_when', :last_id)
  ORDER BY c."when", c.id  --  🠴 ORDER BY spec matches index scan order
  LIMIT  :rows_per_page;


-- Now pick a late connection (almost) at the end of the connection
-- table, again set :last_when, :last_id to that first connection.
SELECT c."when", c.id
FROM   (SELECT c.*
        FROM   connections AS c
        ORDER BY c."when" DESC, c.id DESC
        LIMIT :rows_per_page) AS c
ORDER BY c."when", c.id
LIMIT 1;

--  sets :last_when, :last_id
\gset last_


-- Query submitted by the Web app: produce one page of connections
EXPLAIN (VERBOSE, ANALYZE)
  SELECT c.*
  FROM   connections AS c
  WHERE  (c."when", c.id) >= (:'last_when', :last_id)
  ORDER BY c."when", c.id  --  🠴 ORDER BY spec matches index scan order
  LIMIT  :rows_per_page;

 