-----------------------------------------------------------------------
-- Timestamps/Intervals


SELECT 'now'::date      AS "now (date)",
       'now'::time      AS "now (time)",
       'now'::timestamp AS "now (timestamp)";


-- Timestamps may be optionally annotated with time zones
SELECT 'now'::timestamp AS now,
       'now'::timestamp with time zone AS "now tz";


SELECT '5-4-2020' :: date;  -- April 5, 2020
SELECT '1.2.2020' :: date;  -- feb 1 2020
-- Back to the default datestyle
reset datestyle;

-- Dates may be specified in a variety of forms
SELECT COUNT(DISTINCT birthdays.d::date) AS interpretations
FROM   (VALUES ('August 26, 1968'),
               ('Aug 26, 1968'),
               ('26.8.1968'),
               ('26-8-1968'),
               ('26/8/1968')) AS birthdays(d);

-- Special timestamps and dates
SELECT 'epoch'::timestamp    AS epoch,
       'infinity'::timestamp AS infinity,
       'today'::date         AS today,
       'yesterday'::date     AS yesterday,
       'tomorrow'::date      AS tomorrow;

SELECT 'P1Y2M3DT4H5M6S'::interval;
SELECT 'P1Y'::interval;
SELECT '1 year 2 months 3 days 4 hours 5 minutes 6 seconds'::interval
        =
       'P1Y2M3DT4H5M6S'::interval; -- ISO 8601
--      └──┬──┘└──┬──┘
--   date part   time part


 
SELECT 'Aug 31, 2035'::date - 'now'::timestamp                     AS retirement;
SELECT 'now'::date + '30 days'::interval                           AS in_one_month;
SELECT 'now'::date + 2 * '1 month'::interval                       AS in_two_months;
SELECT 'tomorrow'::date - 'now'::timestamp                         AS til_midnight;
SELECT extract(hours from ('tomorrow'::date - 'now'::timestamp))  AS hours_til_midnight;
SELECT 'tomorrow'::date - 'yesterday'::date                        AS two; -- ⚠ yields int day
SELECT make_interval(days => 'tomorrow'::date - 'yesterday'::date) AS two_days;
 

--                year    month  day
--                 ↓        ↓     ↓
SELECT (make_date(2022, months.m, 1) - '1 day'::interval)::date AS last_day_of_month
FROM   generate_series(1,12) AS months(m);


SELECT timezones.tz AS timezone,
       'now'::timestamp with time zone -- uses default ("show time zone")
         -
       ('now'::timestamp::text || ' ' || timezones.tz)::timestamp with time zone AS difference
FROM   (VALUES ('America/New_York'),
               ('Europe/Berlin'),
               ('Asia/Tokyo'),
               ('PST'),
               ('UTC'),
               ('UTC-6'),
               ('+3')
       ) AS timezones(tz)
ORDER BY difference;

-- Do two periods of date/time overlap (infix operator 'overlaps')?
SELECT holiday.holiday
FROM   (VALUES ('Easter',    'Apr  6, 2020', 'Apr 18, 2020'),
               ('Pentecost', 'Jun  2, 2020', 'Jun 13, 2020'),
               ('Summer',    'Jul 30, 2020', 'Sep  9, 2020'),
               ('Autumn',    'Oct 26, 2020', 'Oct 31, 2020'),
               ('Winter',    'Dec 23, 2020', 'Jan  9, 2021')) AS holiday(holiday, "start", "end")
WHERE    ('1-10-2020','today'::date + '6 months'::interval) overlaps (holiday.start :: date, holiday.end :: date);

