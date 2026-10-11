with source as (
    select * from {{ source('raw', 'order_items') }}
),

renamed as (
    select
        cast(order_id as string)             as order_id,
        cast(order_item_id as int64)         as order_item_id,
        cast(product_id as string)           as product_id,
        cast(seller_id as string)            as seller_id,
        cast(shipping_limit_date as timestamp) as shipping_limit_at,
        cast(price as numeric)               as price,
        cast(freight_value as numeric)       as freight_value
    from source
    where order_id is not null
)

select * from renamed
