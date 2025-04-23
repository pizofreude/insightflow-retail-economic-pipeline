-- models/staging/stg_iowrt_3d.sql

with source_data as (
    -- Select data from the raw source table created by Glue Crawler
    select
        series,
        "date",
        group_code, -- Rename 'group' column
        sales,
        volume
    from {{ source('landing_zone', 'iowrt_3d') }}
    where series = 'abs' -- Filter for absolute values
      and group_code is not null and group_code != '' -- Filter out empty or null values
)

select
    -- Cast data types and rename columns
    cast(from_unixtime(cast("date" as bigint)) as timestamp) as record_date,
    cast(group_code as varchar) as msic_group_code, -- Ensure group code is string
    cast(sales as double) as sales_value_rm_mil,
    cast(volume as double) as volume_index

from source_data
