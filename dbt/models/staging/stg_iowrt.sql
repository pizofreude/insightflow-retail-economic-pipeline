-- models/staging/stg_iowrt.sql

with source_data as (
    -- Select data from the raw source table created by Glue Crawler
    select
        series,
        "date", -- Quoted because date is a reserved keyword in some SQL dialects
        sales,
        volume,
        volume_sa
    from {{ source('landing_zone', 'iowrt') }}
    -- Filter for absolute values as growth figures can be recalculated later if needed
    where series = 'abs'
)

select
    -- Cast data types and rename columns
    date_from_unixtime(cast("date" as bigint)) as record_date,
    cast(sales as double) as sales_value_rm_mil,
    cast(volume as double) as volume_index,
    cast(volume_sa as double) as volume_index_sa

from source_data
-- Optional: Add any other basic filtering or cleaning specific to this source
