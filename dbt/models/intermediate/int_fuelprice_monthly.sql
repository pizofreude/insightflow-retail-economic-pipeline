-- models/intermediate/int_fuelprice_monthly.sql

with monthly_agg as (
    select
        -- Truncate date to the first day of the month
        date_trunc('month', record_date) as year_month_date,
        -- Calculate average prices for the month
        avg(ron95_price_rm) as avg_ron95_price_rm,
        avg(ron97_price_rm) as avg_ron97_price_rm,
        avg(diesel_peninsular_price_rm) as avg_diesel_peninsular_price_rm,
        avg(diesel_eastmsia_price_rm) as avg_diesel_eastmsia_price_rm
    from {{ ref('stg_fuelprice') }}
    group by 1 -- Group by the truncated month date
)

select
    year_month_date,
    -- Optional: Cast averages to a specific precision if needed
    round(avg_ron95_price_rm, 2) as avg_ron95_price_rm,
    round(avg_ron97_price_rm, 2) as avg_ron97_price_rm,
    round(avg_diesel_peninsular_price_rm, 2) as avg_diesel_peninsular_price_rm,
    round(avg_diesel_eastmsia_price_rm, 2) as avg_diesel_eastmsia_price_rm
from monthly_agg
order by year_month_date
