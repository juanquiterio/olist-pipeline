-- BI extract: orders by purchase month, customer state and delivery outcome.
-- Every measure is additive (sums and counts). Compute averages in the BI tool as
-- SUM(numerator) / SUM(denominator), never by averaging averages.
-- purchase_month is formatted YYYYMMDD (first day of the month) so Looker Studio
-- can use it as a date field.

SELECT
    FORMAT_DATE('%Y%m%d', DATE_TRUNC(purchase_date_key, MONTH))      AS purchase_month,
    customer_state,
    CONCAT('BR-', customer_state)                                     AS state_iso,
    CASE
        WHEN is_delivered = 0 OR delivery_delay_days IS NULL THEN '5. Not delivered'
        WHEN is_late = 0                                     THEN '1. On time'
        WHEN delivery_delay_days <= 3                        THEN '2. Late 1-3 days'
        WHEN delivery_delay_days <= 7                        THEN '3. Late 4-7 days'
        ELSE                                                      '4. Late 8+ days'
    END                                                               AS delivery_outcome,
    COUNT(*)                                                          AS orders,
    SUM(is_canceled)                                                  AS canceled_orders,
    SUM(is_delivered)                                                 AS delivered_orders,
    SUM(is_late)                                                      AS late_orders,
    ROUND(CAST(SUM(IF(is_canceled = 0, total_payment_value, 0)) AS FLOAT64), 2) AS revenue,
    SUM(delivery_days)                                                AS delivery_days_sum,
    COUNTIF(delivery_days IS NOT NULL)                                AS delivery_days_n,
    ROUND(SUM(avg_review_score), 4)                                   AS review_score_sum,
    COUNTIF(avg_review_score IS NOT NULL)                             AS reviewed_orders
FROM `${MARTS}.fct_orders`
WHERE customer_state IS NOT NULL
  AND purchase_date_key IS NOT NULL
GROUP BY purchase_month, customer_state, state_iso, delivery_outcome
ORDER BY purchase_month, customer_state, delivery_outcome
