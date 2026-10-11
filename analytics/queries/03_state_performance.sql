-- Business question:
-- Which Brazilian states have the worst delivery performance,
-- and does it correlate with cancellation and satisfaction?

with state_stats as (

    select
        customer_state,
        count(*)                                as total_orders,
        sum(is_canceled)                        as canceled_orders,
        sum(is_late)                            as late_deliveries,
        round(safe_divide(sum(is_canceled), count(*)) * 100, 2) as cancellation_rate_pct,
        round(safe_divide(sum(is_late), count(*)) * 100, 2)     as late_delivery_rate_pct,
        round(avg(delivery_days), 1)            as avg_delivery_days,
        round(avg(delivery_delay_days), 1)      as avg_delay_days,
        round(avg(avg_review_score), 2)         as avg_review_score,
        round(avg(total_payment_value), 2)      as avg_order_value
    from `${MARTS}.fct_orders`
    where customer_state is not null
    group by customer_state

)

select *
from state_stats
where total_orders >= 100
order by avg_review_score asc, late_delivery_rate_pct desc
