with products as (
    select * from {{ ref('stg_products') }}
),

translation as (
    select * from {{ ref('stg_category_translation') }}
),

joined as (
    select
        p.product_id,
        p.category_name                                          as category_name_pt,
        coalesce(t.category_name_en, p.category_name, 'unknown') as category_name_en,
        p.name_length,
        p.description_length,
        p.photos_qty,
        p.weight_g,
        p.length_cm,
        p.height_cm,
        p.width_cm
    from products p
    left join translation t on p.category_name = t.category_name_pt
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['product_id']) }} as product_key,
        product_id,
        category_name_pt,
        category_name_en,
        name_length,
        description_length,
        photos_qty,
        weight_g,
        length_cm,
        height_cm,
        width_cm
    from joined
)

select * from final
