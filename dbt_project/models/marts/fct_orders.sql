with orders as (
    select * from {{ ref('int_orders_enriched') }}
),

customers as (
    select customer_key, customer_id from {{ ref('dim_customers') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['o.order_id']) }} as order_key,
        o.order_id,
        c.customer_key,
        o.customer_state,
        date(o.purchased_at)              as purchase_date_key,
        o.order_status,
        o.purchased_at,
        o.delivered_customer_at,
        o.delivery_days,
        o.estimated_delivery_days,
        o.delivery_delay_days,
        o.total_payment_value,
        o.payment_count,
        o.max_installments,
        o.avg_review_score,
        o.review_count,
        case when o.order_status = 'canceled' then 1 else 0 end as is_canceled,
        case when o.order_status = 'delivered' then 1 else 0 end as is_delivered,
        case when o.delivery_delay_days > 0 then 1 else 0 end as is_late
    from orders o
    left join customers c on o.customer_id = c.customer_id
)

select * from final
