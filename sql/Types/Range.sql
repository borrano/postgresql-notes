SELECT '(1,2]'::int4range;
 
VALUES ('(1,2]'::int4range), ('[3,5]')

SELECT '(1,12]'::int4range * '[3,5]' ::int4range; -- intersection