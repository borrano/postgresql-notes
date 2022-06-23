--https://hakibenita.com/postgresql-hash-index
--https://git.postgresql.org/gitweb/?p=postgresql.git;a=blob;f=src/backend/access/hash/README;hb=HEAD
--https://postgrespro.com/blog/pgsql/4161321
select   opf.opfname as opfamily_name,
         amproc.amproc::regproc AS opfamily_procedure
from     pg_am am,
         pg_opfamily opf,
         pg_amproc amproc
where    opf.opfmethod = am.oid
and      amproc.amprocfamily = opf.oid
and      am.amname = 'hash'
order by opfamily_name,
         opfamily_procedure;

SELECT hashint8(12);
SELECT hashchar('a');


DROP TABLE IF EXISTS indexed;
CREATE TABLE indexed (a int  , a1 int,
                      b text,
                      c numeric(3,2));
INSERT INTO indexed(a, a1, b,c)
        SELECT i, i, md5(i::text), sin(i)
        FROM   generate_series(1,10000) AS i;

CREATE INDEX indexed_a_hash ON indexed USING hash (a);
CREATE INDEX indexed_a1_btree ON indexed USING btree (a1);
CREATE INDEX indexed_b_hash ON indexed USING hash (b);
CREATE INDEX indexed_b_btree ON indexed USING btree (b);

ANALYZE;
VACUUM;

-- sizes, if we create index on int - btree is smaller 
-- hash index size is not influenced by size of data type
SELECT relpages, relname FROM pg_class WHERE relname LIKE 'indexed%';

-- hash index is used
explain (VERBOSE, ANALYZE, BUFFERS)
select * from indexed where a = '2';
explain (VERBOSE, ANALYZE, BUFFERS)
select * from indexed where a1 = '2';


-- hash indexes don't support inequalities
-- btree indexes are used
explain (VERBOSE, ANALYZE, BUFFERS)
select * from indexed where a1 < '2';

 
-- metapage
select hash_page_type(get_raw_page('indexed_a',0));

select ntuples, ffactor, bsize, bmsize, bmshift, maxbucket
from hash_metapage_info(get_raw_page('indexed_a',0));

-- bucket
select hash_page_type(get_raw_page('indexed_a',1));

select *
from hash_page_stats(get_raw_page('indexed_a',1));


-- live_items | dead_items | page_size | free_size | hasho_prevblkno | hasho_nextblkno | hasho_bucket | hasho_flag | hasho_page_id 
--------------+------------+-----------+-----------+-----------------+-----------------+--------------+------------+---------------
--        155 |          0 |      8192 |      5048 |              32 |      4294967295 |            0 |          2 |         65408



 

-----------------------------------------------------------------------------
--- create fresh slate
CREATE EXTENSION "uuid-ossp";

DROP TABLE IF EXISTS indexed;

CREATE TABLE indexed (
    id serial primary key,
    key text not null,
    url text not null
);

--CREATE INDEX indexed_key ON indexed USING hash(key);
CREATE INDEX indexed_key ON indexed USING btree(key);

DO $$
DECLARE
    n INTEGER := 1000000;
    duration INTERVAL := 0;
    start TIMESTAMP;
    uid TEXT;
    url TEXT;
BEGIN
      FOR i IN 1..n LOOP
        uid := uuid_generate_v4()::text;
        url := 'https://www.supercool-url.com/' || round(random() * 10 ^ 6)::text;
        start := clock_timestamp();
          INSERT INTO indexed (key, url) VALUES (uid, url);
        duration := duration + (clock_timestamp() - start);
    END LOOP;
    RAISE NOTICE 'total=% mean=%', duration, extract('epoch' from duration) / n;
END;
$$;

-- Hash: total=00:00:04.372829 mean=0.000004372829000000000000
-- btree total=00:00:06.573773 mean=0.000006573773000000000000