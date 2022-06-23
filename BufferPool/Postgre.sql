show wal_buffers; -- 16Mb

SELECT name,setting,unit,current_setting(name) FROM pg_settings
WHERE name='wal_buffers';

-- shared buffer size
SELECT name,setting,unit,current_setting(name) FROM pg_settings
WHERE name='shared_buffers';

select count(*) from pg_buffercache;

-- file locations
select name,setting from pg_settings where category='File Locations';