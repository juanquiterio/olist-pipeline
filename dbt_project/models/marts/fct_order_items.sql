with items as (
    select * from {{ ref('int_order_items_enriched') }}
),

orders as (
    select * from {{ ref('int_orders_enriched') }}
),

products as (
    select product_key, product_id from {{ ref('dim_products') }}
),

sellers as (
    select seller_key, seller_id from {{ ref('dim_sellers') }}
),

customers as (
    select customer_key, customer_id from {{ ref('dim_customers') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['i.order_id', 'i.order_item_id']) }} as order_item_key,
        i.order_id,
        i.order_item_id,
        p.product_key,
        s.seller_key,
        c.customer_key,
        date(o.purchased_at)              as purchase_date_key,
        i.category_name_en,
        i.price,
        i.freight_value,
        i.total_item_value,
        o.order_status,
        o.customer_state,
        o.delivery_days,
        o.delivery_delay_days,
        o.avg_review_score,
        case when o.order_status = 'canceled' then 1 else 0 end as is_canceled,
        case when o.order_status = 'delivered' then 1 else 0 end as is_delivered,
        case when o.delivery_delay_days > 0 then 1 else 0 end as is_late
    from items i
    inner join orders o on i.order_id = o.order_id
    left join products p on i.product_id = p.product_id
    left join sellers s on i.seller_id = s.seller_id
    left join customers c on o.customer_id = c.customer_id
)

select * from final
