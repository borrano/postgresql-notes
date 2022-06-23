ps -ef | grep postgres | grep -v grep

postgres    1342       1  /usr/lib/postgresql/14/bin/postgres -D /var/lib/postgresql/14/main -c config_file=/etc/postgresql/14/main/postgresql.conf
postgres    1448    1342  postgres: 14/main: checkpointer 
postgres    1449    1342  postgres: 14/main: background writer 
postgres    1450    1342  postgres: 14/main: walwriter 
postgres    1451    1342  postgres: 14/main: autovacuum launcher 
postgres    1452    1342  postgres: 14/main: stats collector 
postgres    1453    1342  postgres: 14/main: logical replication launcher 

--logger: logger process
--checkpointer: checkpointer process
--background writer: writer process
--wal writer: wal writer process
--autovacuum launcher postgres: autovacuum launcher process
--autovacuum worker postgres: autovacuum worker process {PGDATABASE}
--archiver postgres: archiver process last was {ARCHIVEDFILE}
--stats collector postgres: stats collector process


-- what will postgres do if it receives kill signal to one of the processes?

Checkpointer, background writer, and stats collector processes are always started.
wal writer: It does not start in the worker instance of the replication environment. Except for this situation, it always starts.
logger: Start-up in the case where parameter logging_collector to "on" (default:"off")
autovacuum launcher: Start-up in the case where parameter autovacuum to "on" (default: "on")
autovacuum worker: Autovacuum launcher process is started with the interval specified by the parameter 
autovacuum_naptime (default: "1min"); it stops after completing the work
  
Shared buffers created using the shmget system call.

