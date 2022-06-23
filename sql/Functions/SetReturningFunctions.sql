SELECT i
FROM   generate_series(1,10,2) AS i;

SELECT generate_series(1,10,2);
-- 0, -0.1, ..., -2.0
SELECT i
FROM   generate_series(0,-2,-0.1) AS i;

DROP TABLE  IF EXISTS X;

CREATE UNLOGGED TABLE X(xs  ) AS 
VALUES(string_to_array('asd asd', ' ')),(string_to_array('3asd 123 asd', ' '));


SELECT a as index, xs[a] as word FROM X, generate_subscripts(xs, 1) as a;

SELECT t.word, t.idx
FROM regexp_split_to_table('Luke, I am Your Father', '\s+') WITH ORDINALITY AS t(word, idx);

SELECT upper(t.c) AS character, t.pos
FROM   unnest(string_to_array('Luke, I am Your Father', NULL))
       WITH ORDINALITY AS t(c,pos);   


--------------------------------------------------------------------
-- zip set returning functions
SELECT * FROM 
ROWS FROM(generate_series(1,10, 1), generate_series(1,10, 2));
-- zip arrays 
SELECT starwars.*
FROM   unnest(array[4,5,1,2,3,6,7,8,9],          -- episodes
              array['A New Hope',                -- known episode titles
                    'The Empire Strikes Back',
                    'The Phantom Menace',
                    'Attack of the Clones',
                    'Revenge of the Sith',
                    'Return of the Jedi',
                    'The Force Awakens',
                    'The Last Jedi',
                    'The Rise of Skywalker'])
       WITH ORDINALITY AS starwars(episode,film,watch)
ORDER BY watch;
