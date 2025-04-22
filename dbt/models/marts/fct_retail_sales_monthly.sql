-- models/marts/fct_retail_sales_monthly.sql

{{ config(
    materialized='table',
    partitioned_by=['year', 'month']
    clustered_by=['msic_group_key'],
    buckets=16
    )
}}

with trade_data as (
    select
        record_date,
        msic_group_code,
        sales_value_rm_mil,
        volume_index
    from {{ ref('stg_iowrt_3d') }}
),

monthly_fuel as (
    select
        year_month_date,
        avg_ron95_price_rm,
        avg_ron97_price_rm,
        avg_diesel_peninsular_price_rm
        -- Select east malaysia diesel if relevant for your analysis
        -- avg_diesel_eastmsia_price_rm
    from {{ ref('int_fuelprice_monthly') }}
),

date_dim as (
    select
        date_key,
        full_date,
        year,
        month
    from {{ ref('dim_date') }}
),

group_dim as (
    select
        msic_group_key,
        msic_group_code
    from {{ ref('dim_msic_group') }}
)

select
    -- Surrogate keys from dimensions
    coalesce(dd.date_key, cast(date_format(td.record_date, '%Y%m%d') as int)) as date_key, -- Use date dimension key
    coalesce(gd.msic_group_key, 'UNKNOWN') as msic_group_key, -- Use group dimension key, handle unknown

    -- Degenerate dimensions (optional)
    td.record_date,
    td.msic_group_code,

    -- Measures from trade data
    td.sales_value_rm_mil,
    td.volume_index,

    -- Measures from fuel data (joined by month)
    mf.avg_ron95_price_rm,
    mf.avg_ron97_price_rm,
    mf.avg_diesel_peninsular_price_rm,

    -- Partitioning columns (repeated for clarity and use in partition clause)
    extract(YEAR FROM td.record_date) as year,
    extract(MONTH FROM td.record_date) as month

from trade_data td

left join monthly_fuel mf
    -- Join on the first day of the month
    on date_trunc('month', td.record_date) = mf.year_month_date

left join date_dim dd
    on td.record_date = dd.full_date

left join group_dim gd
    on td.msic_group_code = gd.msic_group_code

-- Optional: Add filter if needed, e.g., exclude dates before fuel data starts
-- where td.record_date >= (select min(year_month_date) from monthly_fuel)

