-- Business question:
-- Which product categories have the highest cancellation rates,
-- and how do delivery time and satisfaction relate to them?
--
-- Note: metrics count distinct order_id, not items, so an order
-- with multiple items is only counted once per metric.

with category_stats as (

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
        round(avg(delivery_days), 1)                                                   as avg_delivery_days,
        round(avg(delivery_delay_days), 1)                                             as avg_delay_days,
        round(avg(avg_review_score), 2)                                                as avg_review_score,
        round(sum(price), 2)                                                           as total_revenue

    from `${MARTS}.fct_order_items`
    where category_name_en is not null
      and category_name_en != 'unknown'
    group by category_name_en

)

select *
from category_stats
where total_orders >= 100
order by cancellation_rate_pct desc, total_orders desc
