DROP TABLE IF EXISTS W;
CREATE TABLE W (
  row text PRIMARY KEY,
  a   int,
  b   text
);

INSERT INTO W(row, a, b) VALUES
  ('ϱ1', 1, '⚫'),
  ('ϱ2', 2, '⚪'),
  ('ϱ3', 3, '⚪'),
  ('ϱ4', 3, '⚫'),
  ('ϱ5', 3, '⚪'),
  ('ϱ6', 4, '⚪'),
  ('ϱ7', 6, '⚫'),
  ('ϱ8', 6, '⚫'),
  ('ϱ9', 7, '⚪');


TABLE W;