with order_items as (
    select * from {{ ref('int_order_items_enriched') }}
),

orders as (
    select * from {{ ref('int_orders_enriched') }}
),

joined as (
    select
        oi.order_id,
        oi.order_item_id,
        oi.category_name_en,
        oi.product_id,
        oi.seller_id,
        oi.price,
        oi.freight_value,
        o.order_status,
        o.customer_state,
        o.delivery_days,
        o.delivery_delay_days,
        o.avg_review_score,
        o.purchased_at,
        case
            when o.order_status = 'canceled'  then 1 else 0
        end as is_canceled,
        case
            when o.order_status = 'delivered' then 1 else 0
        end as is_delivered,
        case
            when o.delivery_delay_days > 0 then 1 else 0
        end as is_late
    from order_items oi
    inner join orders o on oi.order_id = o.order_id
),

aggregated as (
    select
        category_name_en,
        count(distinct order_id)                                                       as total_orders,
        count(*)                                                                       as total_items,
        count(distinct case when is_canceled = 1  then order_id end)                   as canceled_orders,
        count(distinct case when is_delivered = 1 then order_id end)                   as delivered_orders,
        count(distinct case when is_late = 1      then order_id end)                   as late_orders,
        round(safe_divide(
            count(distinct case when is_canceled = 1 then order_id end),
            count(distinct order_id)
        ) * 100, 2)                                                                    as cancellation_rate_pct,
        round(safe_divide(
            count(distinct case when is_late = 1 then order_id end),
            nullif(count(distinct case when is_delivered = 1 then order_id end), 0)
        ) * 100, 2)                                                                    as late_delivery_rate_pct,
        round(avg(delivery_days), 2)                                                   as avg_delivery_days,
        round(avg(delivery_delay_days), 2)                                             as avg_delay_days,
        round(avg(avg_review_score), 2)                                                as avg_review_score,
        round(sum(price), 2)                                                           as total_revenue,
        round(avg(price), 2)                                                           as avg_item_price
    from joined
    group by category_name_en
)

select * from aggregated
