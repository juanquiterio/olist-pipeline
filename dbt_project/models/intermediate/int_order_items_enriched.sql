with items as (
    select * from {{ ref('stg_order_items') }}
),

products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_category_translation') }}
),

sellers as (
    select * from {{ ref('stg_sellers') }}
),

enriched as (
    select
        i.order_id,
        i.order_item_id,
        i.product_id,
        p.category_name                          as category_name_pt,
     coalesce(t.category_name_en, p.category_name, 'unknown') as category_name_en,
        p.weight_g,
        p.length_cm,
        p.height_cm,
        p.width_cm,
        i.seller_id,
        s.city                                   as seller_city,
        s.state                                  as seller_state,
        i.price,
        i.freight_value,
        i.price + i.freight_value                as total_item_value,
        i.shipping_limit_at
    from items i
    left join products p on i.product_id = p.product_id
    left join translation t on p.category_name = t.category_name_pt
    left join sellers s on i.seller_id = s.seller_id
)

select * from enriched
