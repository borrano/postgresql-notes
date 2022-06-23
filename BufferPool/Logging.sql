
-- https://www.postgresql.org/docs/current/runtime-config-logging.html
parameters 
in postgresql.conf file log_statement

SELECT pg_ls_logdir();
select pg_current_logfile() ;