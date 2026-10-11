-- BI extract: order items by purchase month, customer state and product category.
-- Grain is the order item, so "items" must not be read as "orders" (an order can
-- contain several categories). Order-level scores are repeated for each item.
-- Revenue excludes canceled items.

SELECT
    FORMAT_DATE('%Y%m%d', DATE_TRUNC(purchase_date_key, MONTH))      AS purchase_month,
    customer_state,
    COALESCE(category_name_en, 'unknown')                             AS category,
    COUNT(*)                                                          AS items,
    ROUND(CAST(SUM(IF(is_canceled = 0, price, 0)) AS FLOAT64), 2)     AS revenue,
    SUM(is_canceled)                                                  AS canceled_items,
    SUM(is_delivered)                                                 AS delivered_items,
    SUM(is_late)                                                      AS late_items,
    ROUND(SUM(avg_review_score), 4)                                   AS review_score_sum,
    COUNTIF(avg_review_score IS NOT NULL)                             AS reviewed_items
FROM `${MARTS}.fct_order_items`
WHERE customer_state IS NOT NULL
  AND purchase_date_key IS NOT NULL
GROUP BY purchase_month, customer_state, category
ORDER BY purchase_month, customer_state, category
