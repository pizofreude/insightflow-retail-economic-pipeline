-- models/staging/stg_msic_lookup.sql

with source_data as (
    -- Select data from the seed file
    -- Ensure your msic_lookup.csv has headers: group_code, desc_en, desc_bm
    select
        group_code, -- this column name in CSV holds the 3-digit code
        desc_en,    -- this column name for English description
        desc_bm     -- this column name for Malay description
        -- Add other columns from the seed if needed
    from {{ ref('msic_lookup') }} -- Reference the seed file (msic_lookup.csv)
    where group_code is not null and group_code != '' -- Filter out empty or null values
)

select
    -- Cast data types and rename columns if necessary
    cast(group_code as varchar) as msic_group_code,
    cast(desc_en as varchar) as group_desc_en,
    cast(desc_bm as varchar) as group_desc_bm
    -- Select other columns if needed

from source_data
-- Filter for only 3-digit codes if your seed contains other levels
-- Assuming 3-digit codes have length 3
-- where length(trim(group_code)) = 3

