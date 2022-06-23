DROP TABLE IF EXISTS ts;
create table ts(doc text, doc_tsv tsvector);
insert into ts(doc) values
  ('Can a sheet slitter slit sheets?'), 
  ('How many sheets could a sheet slitter slit?'),
  ('I slit a sheet, a sheet I slit.'),
  ('Upon a slitted sheet I sit.'), 
  ('Whoever slit the sheets is a good sheet slitter.'), 
  ('I am a sheet slitter.'),
  ('I slit sheets.'),
  ('I am the sleekest sheet slitter that ever slit sheets.'),
  ('She slits the sheet she sits on.');

update ts set doc_tsv = to_tsvector(doc);
create index ts_doc on ts using gin(doc_tsv);

select ctid, left(doc,20), doc_tsv from ts;

ANALYZE;
VACUUM;

set enable_seqscan = 'off';
explain ANALYZE
select doc from ts where doc_tsv @@ to_tsquery('many & slitter');
