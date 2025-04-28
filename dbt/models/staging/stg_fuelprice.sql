-- models/staging/stg_fuelprice.sql

with source_data as (
    -- Select data from the raw source table created by Glue Crawler
    select
        series_type,
        -- Convert ymd_date from nanoseconds to a proper timestamp and alias it as record_date
        from_unixtime(cast(ymd_date / 1000000000 as bigint)) as record_date,
        ron95,
        ron97,
        diesel,
        diesel_eastmsia
    from {{ source('landing_zone', 'fuelprice') }}
    -- Filter for actual price levels, not weekly changes
    where series_type = 'level'
)

select
    -- Use record_date as the alias for the converted timestamp
    record_date,
    cast(ron95 as double) as ron95_price_rm,
    cast(ron97 as double) as ron97_price_rm,
    cast(diesel as double) as diesel_peninsular_price_rm,
    cast(diesel_eastmsia as double) as diesel_eastmsia_price_rm

from source_data
