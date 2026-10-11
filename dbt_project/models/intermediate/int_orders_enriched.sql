with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

payments as (
    select
        order_id,
        sum(payment_value)                                          as total_payment_value,
        count(*)                                                    as payment_count,
        max(payment_installments)                                   as max_installments,
        string_agg(distinct payment_type, ', ' order by payment_type) as payment_types
    from {{ ref('stg_order_payments') }}
    group by order_id
),

reviews as (
    select
        order_id,
        avg(review_score)       as avg_review_score,
        min(review_score)       as min_review_score,
        count(*)                as review_count
    from {{ ref('stg_order_reviews') }}
    group by order_id
),

enriched as (
    select
        o.order_id,
        o.customer_id,
        c.customer_unique_id,
        c.city              as customer_city,
        c.state             as customer_state,
        o.order_status,
        o.purchased_at,
        o.approved_at,
        o.delivered_carrier_at,
        o.delivered_customer_at,
        o.estimated_delivery_at,
        -- Derivated metrics
        timestamp_diff(o.delivered_customer_at, o.purchased_at, day)    as delivery_days,
        timestamp_diff(o.estimated_delivery_at, o.purchased_at, day)    as estimated_delivery_days,
        timestamp_diff(o.delivered_customer_at, o.estimated_delivery_at, day) as delivery_delay_days,
        coalesce(p.total_payment_value, 0) as total_payment_value,
        coalesce(p.payment_count, 0)       as payment_count,
        p.max_installments,
        p.payment_types,
        r.avg_review_score,
        r.min_review_score,
        coalesce(r.review_count, 0) as review_count
    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join payments p on o.order_id = p.order_id
    left join reviews r on o.order_id = r.order_id
)

select * from enriched
