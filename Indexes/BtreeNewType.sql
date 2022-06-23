--------------------
-- In this file - new type for btree
DROP TABLE IF EXISTS numbers; 
DROP TYPE IF EXISTS complex CASCADE;

create type complex as (re float, im float);
create table numbers(x complex);
insert into numbers (x)
SELECT (random(), random())::complex FROM generate_series (1, 1000, 1);

select * from numbers order by x;

create function modulus(a complex) returns float as $$
    select sqrt(a.re*a.re + a.im*a.im);
$$ immutable language sql;

create function complex_lt(a complex, b complex) returns boolean as $$
    select modulus(a) < modulus(b);
$$ immutable language sql;

create function complex_le(a complex, b complex) returns boolean as $$
    select modulus(a) <= modulus(b);
$$ immutable language sql;

create function complex_eq(a complex, b complex) returns boolean as $$
    select modulus(a) = modulus(b);
$$ immutable language sql;

create function complex_ge(a complex, b complex) returns boolean as $$
    select modulus(a) >= modulus(b);
$$ immutable language sql;

create function complex_gt(a complex, b complex) returns boolean as $$
    select modulus(a) > modulus(b);
$$ immutable language sql;

create operator #<#(leftarg=complex, rightarg=complex, procedure=complex_lt);
create operator #<=#(leftarg=complex, rightarg=complex, procedure=complex_le);
create operator #=#(leftarg=complex, rightarg=complex, procedure=complex_eq);
create operator #>=#(leftarg=complex, rightarg=complex, procedure=complex_ge);
create operator #>#(leftarg=complex, rightarg=complex, procedure=complex_gt);

select (2.0,1.0)::complex #<# (1.0,3.0)::complex;

create function complex_cmp(a complex, b complex) returns integer as $$
    select case when modulus(a) < modulus(b) then -1
                when modulus(a) > modulus(b) then 1 
                else 0
           end;
$$ language sql;

create operator class complex_ops
default for type complex
using btree as
    operator 1 #<#,
    operator 2 #<=#,
    operator 3 #=#,
    operator 4 #>=#,
    operator 5 #>#,
    function 1 complex_cmp(complex,complex);

select * from numbers order by x;

CREATE INDEX numbers_x_complex ON numbers USING btree(x complex_ops);

ANALYZE; 

-- index only scan 
-- 
EXPLAIN ANALYZE
select * from numbers order by x LIMIT 10;
