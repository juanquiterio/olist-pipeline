with source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (
    select
        cast(customer_id as string)             as customer_id,
        cast(customer_unique_id as string)      as customer_unique_id,
        cast(customer_zip_code_prefix as int64) as zip_code_prefix,
        cast(customer_city as string)           as city,
        upper(cast(customer_state as string))   as state
    from source
    where customer_id is not null
)

select * from renamed
