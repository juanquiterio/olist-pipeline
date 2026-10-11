with source as (
    select * from {{ source('raw', 'order_reviews') }}
),

renamed as (
    select
        cast(review_id as string)                  as review_id,
        cast(order_id as string)                   as order_id,
        cast(review_score as int64)                as review_score,
        cast(review_comment_title as string)       as review_comment_title,
        cast(review_comment_message as string)     as review_comment_message,
        cast(review_creation_date as timestamp)    as review_created_at,
        cast(review_answer_timestamp as timestamp) as review_answered_at
    from source
    where review_id is not null
)

select * from renamed
