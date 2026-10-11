with dates as (
    select distinct date(purchased_at) as date_key
    from {{ ref('stg_orders') }}
    where purchased_at is not null
),

final as (
    select
        date_key,
        extract(year from date_key)      as year,
        extract(month from date_key)     as month,
        extract(day from date_key)       as day,
        extract(quarter from date_key)   as quarter,
        extract(dayofweek from date_key) as day_of_week,
        format_date('%A', date_key)      as day_name,
        format_date('%B', date_key)      as month_name
    from dates
)

select * from final
