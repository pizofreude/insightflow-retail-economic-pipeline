-- models/marts/dim_msic_group.sql

{{ config(materialized='table') }}

with staging as (
    select
        msic_group_code,
        group_desc_en,
        group_desc_bm
    from {{ ref('stg_msic_lookup') }}
    -- Ensure uniqueness if the staging model didn't already
    group by 1, 2, 3
)
select
    -- Generate a surrogate key (optional but good practice)
    -- Using hash of the natural key (msic_group_code)
    {{ dbt_utils.generate_surrogate_key(['msic_group_code']) }} as msic_group_key,
    msic_group_code,
    group_desc_en,
    group_desc_bm
from staging
