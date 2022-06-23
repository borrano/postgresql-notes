-----------------------------------------------------------------------
-- Enumerations

--            deletes tables with episode columns
--                             ↓

DROP TYPE IF EXISTS episode CASCADE;
CREATE TYPE episode AS ENUM
  ('ANH', 'ESB', 'TPM', 'AOTC', 'ROTS', 'ROTJ', 'TFA', 'TLJ', 'TROS');

DROP TABLE IF EXISTS starwars;
CREATE TABLE starwars(film    episode PRIMARY KEY,
                      title   text,
                      release date);
-- string cast
INSERT INTO starwars(film,title,release) VALUES
    ('TPM',  'The Phantom Menace',      'May 19, 1999'),
    ('AOTC', 'Attack of the Clones',    'May 16, 2002'),
    ('ROTS', 'Revenge of the Sith',     'May 19, 2005'),
    ('ANH',  'A New Hope',              'May 25, 1977'),
    ('ESB',  'The Empire Strikes Back', 'May 21, 1980'),
    ('ROTJ', 'Return of the Jedi',      'May 25, 1983'),
    ('TFA',  'The Force Awakens',       'Dec 18, 2015'),
    ('TLJ',  'The Last Jedi',           'Dec 15, 2017'),
    ('TROS', 'The Rise of Skywalker',   'Dec 19, 2019');
--     ↑              ↑                        ↑
-- ::episode       ::text                    ::date

INSERT INTO starwars(film,title,release) VALUES
  ('R1', 'Rogue One', 'Dec 15, 2016');
--   ↑
-- ⚠ not an episode value

-- Order of enumerated type yields the Star Wars Machete order
SELECT s.*
FROM   starwars AS s
ORDER BY s.film; -- s.release; -- yields chronological order

SELECT MIN(s.film)
FROM   starwars AS s;
 
