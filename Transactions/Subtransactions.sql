https://www.cybertec-postgresql.com/en/subtransactions-and-performance-in-postgresql/

BEGIN;
SELECT 'Some work is done';
SAVEPOINT a;
SELECT 12 / (factorial(0) - 1);
ROLLBACK TO SAVEPOINT a;
SELECT 'try to do more work';
COMMIT;

