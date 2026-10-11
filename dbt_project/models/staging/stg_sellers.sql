with source as (
    select * from {{ source('raw', 'sellers') }}
),

renamed as (
    select
        cast(seller_id as string)              as seller_id,
        cast(seller_zip_code_prefix as int64)  as zip_code_prefix,
        cast(seller_city as string)            as city,
        upper(cast(seller_state as string))    as state
    from source
    where seller_id is not null
)

select * from renamed
