-- RFM-сегментация клиентов (только доставленные заказы).
-- F считается через CASE: у ~97% клиентов один заказ, NTILE по частоте бессмыслен.

-- name: rfm_segments
WITH metrics AS (
    SELECT c.customer_unique_id,
           MAX(o.order_purchase_timestamp) AS last_order,
           COUNT(DISTINCT o.order_id)      AS frequency,
           SUM(oi.price)                   AS monetary
    FROM customers c
    JOIN orders o       ON c.customer_id = o.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY 1
),
metrics_plus_recency AS (
    -- точка отсчёта: последний доставленный заказ в данных
    SELECT *,
           EXTRACT(DAY FROM (SELECT MAX(order_purchase_timestamp) FROM orders
                             WHERE order_status = 'delivered') - last_order) AS recency_days
    FROM metrics
),
score AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
           CASE WHEN frequency > 1 THEN 2 ELSE 1 END AS f_score,
           NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM metrics_plus_recency
),
segments AS (
    SELECT *,
           CASE WHEN r_score >= 4 AND m_score >= 4 THEN 'лучшие'
                WHEN r_score >= 4 AND m_score < 4 AND f_score = 1 THEN 'новые'
                WHEN r_score <= 2 AND m_score >= 4 THEN 'уходящие'
                WHEN f_score = 2 THEN 'повторные'
                ELSE 'потерянные'
           END AS seg
    FROM score
)
SELECT seg,
       COUNT(*) AS customers,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM segments), 2) AS pct,
       ROUND(AVG(monetary), 2)     AS avg_monetary,
       ROUND(AVG(recency_days)::numeric, 0) AS avg_recency_days
FROM segments
GROUP BY seg
ORDER BY customers DESC;
