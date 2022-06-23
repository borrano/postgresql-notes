
-----------------------------------------------------------------------
-- Text data types

-- truncates
SELECT '01234' :: char(3);   -- truncation to enforce limit after cast
--     └──┬──┘               -- NB: column name is `bpchar': blank-padded characters,
--      text                 --     PostgreSQL-internal name for char(‹n›)


-- Blank-padding when storing/printing char(‹n›)
SELECT t.c :: char(10)
FROM   (VALUES ('01234'),    -- padding with 5 × '␣' padding when result is printed
               ('0123456789')
       ) AS t(c);



-- Character length vs. storage size in bytes (PostgreSQL built-in function octet_length())
-- length vs utf8 length
SELECT t.c,
       length(t.c)       AS chars,
       octet_length(t.c) AS bytes
FROM   (VALUES ('x'),
               ('⚠'), -- ⚠ = U+26A0, in UTF8: 0xE2 0x9A 0xA0
               ('👩🏾')
       ) AS t(c);


-- Decide the default character encoding when database instance is created
-- (see https://www.postgresql.org/docs/current/multibyte.html)


-- text length vs length 

SELECT octet_length('012346789' :: varchar(5)) AS c1, -- 5 (truncation)
       octet_length('012'       :: varchar(5)) AS c2, -- 3 (within limits)
       octet_length('012'       :: char(5))    AS c3, -- 5 (blank padding in storage)
       length('012'             :: char(5))    AS c4, -- 3 (padding in storage only)
       length('012  '           :: char(5))    AS c5; -- 3 (trailing blanks removed)

