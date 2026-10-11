-- Business question:
-- Which product categories drive the most revenue,
-- and how do their average item prices and freight costs compare?

with category_revenue as (

    select
        category_name_en,
        count(*)                            as total_items,
        count(distinct order_id)            as total_orders,
        round(sum(price), 2)                as total_revenue,
        round(avg(price), 2)                as avg_item_price,
        round(avg(freight_value), 2)        as avg_freight,
        round(safe_divide(avg(freight_value), avg(price)) * 100, 2) as freight_to_price_pct,
        round(sum(price) / sum(sum(price)) over () * 100, 2) as pct_of_total_revenue

    from `${MARTS}.fct_order_items`
    where category_name_en is not null
      and category_name_en != 'unknown'
    group by category_name_en

)

select *
from category_revenue
where total_items >= 100
order by total_revenue desc
limit 20
