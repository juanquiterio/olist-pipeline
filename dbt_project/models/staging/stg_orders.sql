with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        cast(order_id as string)                          as order_id,
        cast(customer_id as string)                       as customer_id,
        cast(order_status as string)                      as order_status,
        cast(order_purchase_timestamp as timestamp)       as purchased_at,
        cast(order_approved_at as timestamp)              as approved_at,
        cast(order_delivered_carrier_date as timestamp)   as delivered_carrier_at,
        cast(order_delivered_customer_date as timestamp)  as delivered_customer_at,
        cast(order_estimated_delivery_date as timestamp)  as estimated_delivery_at
    from source
    where order_id is not null
)

select * from renamed
