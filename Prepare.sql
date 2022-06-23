-- reusing execution plans

-- generic plan 
-- what is the problem:
--  selectivity changes with parameters - if data is skewed there is no best plan (index scan vs sequential scan)
-- 