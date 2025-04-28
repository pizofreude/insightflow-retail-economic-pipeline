-- models/staging/stg_iowrt_3d.sql

with source_data as (
    -- Select data from the raw source table created by Glue Crawler
    select
        series,
        cast(ymd_date as date) as record_date, -- Directly cast timestamp to date, Updated column name
        group_code, -- Rename 'group' column
        sales,
        volume
    from {{ source('landing_zone', 'iowrt_3d') }}
    where series = 'abs' -- Filter for absolute values
      and group_code is not null and group_code != '' -- Filter out empty or null values
)

select
    -- Cast data types and rename columns
    record_date,
    cast(group_code as varchar) as msic_group_code, -- Ensure group code is string
    cast(sales as double) as sales_value_rm_mil,
    cast(volume as double) as volume_index

from source_data
