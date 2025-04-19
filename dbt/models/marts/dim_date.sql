-- models/marts/dim_date.sql
-- Requires dbt-utils package (add to packages.yml, run dbt deps)

-- Configure model as table
{{ config(materialized='table') }}

-- Generate a date spine from the earliest to latest date in the relevant staging tables
with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2017-01-01' as date)", -- Adjust start date if needed based on data history
        end_date="date_add('month', 1, current_date)" -- Go one month into the future to be safe
       )
    }}
),

-- Find min/max dates from fact sources to limit the spine if desired (optional optimization)
-- date_ranges as (
--     select min(record_date) as min_dt, max(record_date) as max_dt from {{ ref('stg_iowrt') }} union all
--     select min(record_date) as min_dt, max(record_date) as max_dt from {{ ref('stg_iowrt_3d') }} union all
--     select min(record_date) as min_dt, max(record_date) as max_dt from {{ ref('stg_fuelprice') }}
-- ),
-- final_date_range as (
--     select min(min_dt) as start_date, max(max_dt) as end_date from date_ranges
-- )

final_dates as (
    select cast(date_day as date) as full_date
    from date_spine
    -- Optional: join with final_date_range to filter spine
    -- cross join final_date_range
    -- where cast(date_day as date) >= final_date_range.start_date
    --   and cast(date_day as date) <= final_date_range.end_date
)

select
    full_date,
    -- Use date functions compatible with Athena/Trino/Presto
    -- See: https://trino.io/docs/current/functions/datetime.html
    cast(date_format(full_date, '%Y%m%d') as int) as date_key, -- Example surrogate key YYYYMMDD
    extract(YEAR FROM full_date) as year,
    extract(MONTH FROM full_date) as month,
    extract(DAY FROM full_date) as day,
    extract(QUARTER FROM full_date) as quarter,
    extract(YEAR_OF_WEEK FROM full_date) as year_of_week,
    extract(WEEK FROM full_date) as week_of_year, -- ISO week number
    extract(DAY_OF_WEEK FROM full_date) as day_of_week, -- 1(Mon) to 7(Sun) or 0(Sun) to 6(Sat) depending on locale/config
    extract(DAY_OF_YEAR FROM full_date) as day_of_year,
    date_format(full_date, '%Y-%m') as year_month, -- YYYY-MM format
    date_trunc('month', full_date) as first_day_of_month,
    date_format(full_date, '%W') as day_name -- Full day name (e.g., Monday)

from final_dates
