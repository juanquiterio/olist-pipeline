with source as (
    select * from {{ source('raw', 'category_translation') }}
),

renamed as (
    select
        cast(product_category_name as string)         as category_name_pt,
        cast(product_category_name_english as string) as category_name_en
    from source
    where product_category_name is not null
)

select * from renamed
