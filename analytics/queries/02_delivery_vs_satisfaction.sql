-- Business question:
-- How does delivery delay impact customer satisfaction (review score)?
-- What is the threshold where satisfaction drops sharply?

with buckets as (

    select
        order_id,
        avg_review_score,
        delivery_days,
        delivery_delay_days,
        case
            when delivery_delay_days is null then 'not_delivered'
            when delivery_delay_days <= -10 then '10+ days early'
            when delivery_delay_days between -9 and -1 then '1-9 days early'
            when delivery_delay_days = 0 then 'on time'
            when delivery_delay_days between 1 and 3 then '1-3 days late'
            when delivery_delay_days between 4 and 7 then '4-7 days late'
            when delivery_delay_days between 8 and 15 then '8-15 days late'
            else '15+ days late'
        end as delay_bucket
    from `${MARTS}.fct_orders`
    where order_status = 'delivered'
      and avg_review_score is not null
      and delivery_delay_days is not null

),

aggregated as (

    select
        delay_bucket,
        count(*)                          as total_orders,
        round(avg(avg_review_score), 2)   as avg_review_score,
        round(avg(delivery_days), 1)      as avg_delivery_days,
        round(safe_divide(sum(case when avg_review_score <= 2 then 1 else 0 end), count(*)) * 100, 2) as pct_bad_reviews
    from buckets
    group by delay_bucket

)

select *
from aggregated
order by
    case delay_bucket
        when '10+ days early'  then 1
        when '1-9 days early'  then 2
        when 'on time'         then 3
        when '1-3 days late'   then 4
        when '4-7 days late'   then 5
        when '8-15 days late'  then 6
        when '15+ days late'   then 7
        else 8
    end
