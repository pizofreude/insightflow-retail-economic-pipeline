-- models/marts/dim_msic_group.sql

{{ config(materialized='table') }}

with deduplicated as (
    select
        msic_group_code, -- Use the renamed column from stg_msic_lookup
        string_agg(desc_en, '; ') as group_desc_en, -- Concatenate English descriptions
        string_agg(desc_bm, '; ') as group_desc_bm  -- Concatenate Malay descriptions
    from {{ ref('stg_msic_lookup') }}
    -- Ensure uniqueness if the staging model didn't already
    group by msic_group_code
)

select
    -- Generate a surrogate key (optional but good practice)
    -- Using hash of the natural key (msic_group_code)
    {{ dbt_utils.generate_surrogate_key(['msic_group_code']) }} as msic_group_key,
    msic_group_code,
    group_desc_en,
    group_desc_bm
from deduplicated
