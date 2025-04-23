-- models/staging/stg_fuelprice.sql

with source_data as (
    -- Select data from the raw source table created by Glue Crawler
    select
        series_type,
        "date",
        ron95,
        ron97,
        diesel,
        diesel_eastmsia
    from {{ source('landing_zone', 'fuelprice') }}
    -- Filter for actual price levels, not weekly changes
    where series_type = 'level'
)

select
    -- Cast data types and rename columns
    date_from_unixtime(cast("date" as bigint)) as record_date,
    cast(ron95 as double) as ron95_price_rm,
    cast(ron97 as double) as ron97_price_rm,
    cast(diesel as double) as diesel_peninsular_price_rm,
    cast(diesel_eastmsia as double) as diesel_eastmsia_price_rm

from source_data
