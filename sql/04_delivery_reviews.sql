-- Доставка и отзывы: как опоздание влияет на оценку.
-- Отзыв: последний по дате, если их несколько (см. orders_mart).

-- name: delivery_status_share
SELECT CASE
           WHEN order_delivered_customer_date IS NULL THEN 'нет даты'
           WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'вовремя'
           ELSE 'опоздание'
       END AS delivery_status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct
FROM orders
WHERE order_status = 'delivered'
GROUP BY 1
ORDER BY orders DESC;

-- name: delivery_time_stats
SELECT ROUND(AVG(EXTRACT(EPOCH FROM order_delivered_customer_date - order_purchase_timestamp) / 86400)::numeric, 1)
           AS avg_delivery_days,
       ROUND(AVG(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
                      THEN EXTRACT(EPOCH FROM order_delivered_customer_date - order_estimated_delivery_date) / 86400
                 END)::numeric, 1) AS avg_days_late_among_late
FROM orders
WHERE order_status = 'delivered';

-- name: delivery_vs_review
SELECT is_late,
       COUNT(*) AS orders,
       ROUND(AVG(review_score), 2) AS avg_score,
       ROUND(100.0 * COUNT(CASE WHEN review_score IN (1, 2) THEN 1 END) / COUNT(review_score), 1) AS neg_pct
FROM orders_mart
WHERE order_status = 'delivered' AND is_late IS NOT NULL
GROUP BY is_late
ORDER BY is_late DESC;

-- name: days_late_vs_review
-- чем сильнее опоздание, тем хуже оценка
WITH last_review AS (
    SELECT order_id, review_score,
           ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY review_answer_timestamp DESC) AS rn
    FROM order_reviews
),
delivered AS (
    SELECT order_id,
           order_delivered_customer_date,
           order_estimated_delivery_date,
           order_delivered_customer_date::date - order_estimated_delivery_date::date AS days_late
    FROM orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
)
SELECT CASE
           WHEN d.order_delivered_customer_date <= d.order_estimated_delivery_date THEN '0. вовремя'
           WHEN d.days_late <= 3  THEN '1. до 3 дней'
           WHEN d.days_late <= 7  THEN '2. 4-7 дней'
           WHEN d.days_late <= 14 THEN '3. 8-14 дней'
           ELSE '4. больше 14 дней'
       END AS lateness,
       COUNT(*) AS orders,
       ROUND(AVG(r.review_score), 2) AS avg_score,
       ROUND(100.0 * COUNT(CASE WHEN r.review_score IN (1, 2) THEN 1 END) / COUNT(r.review_score), 1) AS neg_pct
FROM delivered d
LEFT JOIN last_review r ON r.order_id = d.order_id AND r.rn = 1
GROUP BY 1
ORDER BY 1;
