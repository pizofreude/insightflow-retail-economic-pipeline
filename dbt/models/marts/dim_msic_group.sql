-- models/marts/dim_msic_group.sql

{{ config(materialized='table') }}

with ranked_descriptions as (
    select
        msic_group_code,  -- Use the renamed column from stg_msic_lookup
        group_desc_en as desc_en, -- Use the alias from stg_msic_lookup
        group_desc_bm as desc_bm, -- Use the alias from stg_msic_lookup
        row_number() over (
            partition by msic_group_code
            order by length(group_desc_en) desc, length(group_desc_bm) desc
        ) as rank
    from {{ ref('stg_msic_lookup') }}
)

select
    -- Generate a surrogate key (optional but good practice)
    -- Using hash of the natural key (msic_group_code)
    {{ dbt_utils.generate_surrogate_key(['msic_group_code']) }} as msic_group_key,
    msic_group_code,
    desc_en as group_desc_en,
    desc_bm as group_desc_bm
from ranked_descriptions
where rank = 1



