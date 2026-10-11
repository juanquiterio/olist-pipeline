with customers as (
    select * from {{ ref('stg_customers') }}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['customer_id']) }} as customer_key,
        customer_id,
        customer_unique_id,
        zip_code_prefix,
        city,
        state
    from customers
)

select * from final
