DROP TABLE IF EXISTS indexed;
CREATE TABLE indexed (a int  ,
                      b text,
                      c numeric(3,2));
INSERT INTO indexed(a,b,c)
        SELECT i, md5(i::text), sin(i)
        FROM   generate_series(1,10000) AS i;
CREATE INDEX indexed_a ON indexed USING btree (a);

VACUUM;

--- access methods 
select amname from pg_am;
	
-- heap, btree, hash, gist, gin, spgist, brin

-- The following four properties are those of the access method:
select a.amname, p.name, pg_indexam_has_property(a.oid,p.name)
from pg_am a, unnest(array['can_order','can_unique','can_multi_col','can_exclude']) p(name)
order by a.amname;

--can_order.     The access method enables us to specify the sort order for values when an index is created (only applicable to "btree" so far).
--can_unique.    Support of the unique constraint and primary key (only applicable to "btree").
--can_multi_col.    An index can be built on several columns.
--can_exclude.    Support of the exclusion constraint EXCLUDE.

select p.name, pg_index_has_property('indexed_a'::regclass,p.name)
from unnest(array[ 'clusterable','index_scan','bitmap_scan','backward_scan']) p(name);
--  clusterable   | t
--  index_scan    | t
--  bitmap_scan   | t
--  backward_scan | t

--clusterable.    A possibility to reorder rows according to the index (clustering with the same-name command CLUSTER).
--index_scan.    Support of index scan. Although this property may seem odd, not all indexes can return TIDs one by one - some return results all at once and support only bitmap scan.
--bitmap_scan.    Support of bitmap scan.
--backward_scan.    The result can be returned in the reverse order of the one specified when building the index.

select p.name,
     pg_index_column_has_property('indexed_a'::regclass,1,p.name)
from unnest(array[
       'asc','desc','nulls_first','nulls_last','orderable','distance_orderable',
       'returnable','search_array','search_nulls'
     ]) p(name);



select opfname, opcname, opcintype::regtype, (select amname from pg_am WHERE  oid = opf.opfmethod)
from pg_opclass opc, pg_opfamily opf
where opf.opfname IN ('integer_ops', 'datetime_ops', 'text_pattern_ops')
and opc.opcfamily = opf.oid
ORDER BY opf.opfname, opf.oid
 
-- For example, which data types can a certain access method manipulate?
select opcname, opcintype::regtype
from pg_opclass
where opcmethod = (select oid from pg_am where amname = 'btree')
order by opcintype::regtype::text;

-- Which operators does an operator class contain (and therefore, 
-- index access can be used for a condition that includes such an operator)?

select amop.amopopr::regoperator
from pg_opclass opc, pg_opfamily opf, pg_am am, pg_amop amop
where opc.opcname = 'array_ops'
    and opf.oid = opc.opcfamily
    and am.oid = opf.opfmethod
    and amop.amopfamily = opc.opcfamily
    and am.amname = 'btree'
    and amop.amoplefttype = opc.opcintype;

select amop.amopopr::regoperator
from pg_opclass opc, pg_opfamily opf, pg_am am, pg_amop amop
where  opc.opcname = 'array_ops'
       and   opf.oid = opc.opcfamily
        and am.oid = opf.opfmethod
        and amop.amopfamily = opc.opcfamily
        and am.amname = 'gin'
        and amop.amoplefttype = opc.opcintype;


