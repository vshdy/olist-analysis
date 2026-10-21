-- Витрина заказов: одна строка = один заказ.
-- Основа для остальных запросов проекта.
-- В pgAdmin создавалась внутри BEGIN ... COMMIT; проверка: COUNT(*) = COUNT(DISTINCT order_id) = 99 441.

-- name: orders_mart
CREATE OR REPLACE VIEW orders_mart AS
WITH items AS (                      -- одна строка на заказ
    SELECT order_id,
           COUNT(*)           AS items_count,
           SUM(price)         AS revenue,
           SUM(freight_value) AS freight
    FROM order_items
    GROUP BY order_id
),
last_review AS (                     -- последний отзыв по каждому заказу
    SELECT order_id,
           review_score,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_answer_timestamp DESC) AS rn
    FROM order_reviews
)
SELECT o.order_id,
       c.customer_unique_id,
       c.customer_state,
       o.order_status,
       o.order_purchase_timestamp,
       DATE_TRUNC('month', o.order_purchase_timestamp)::date AS purchase_month,
       i.items_count,
       i.revenue,
       i.freight,
       o.order_delivered_customer_date::date - o.order_purchase_timestamp::date AS delivery_days,
       CASE
           WHEN o.order_delivered_customer_date IS NULL THEN NULL
           WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'on_time'
           ELSE 'late'
       END AS is_late,
       r.review_score
FROM orders o
JOIN customers c        ON c.customer_id = o.customer_id
LEFT JOIN items i       ON i.order_id = o.order_id
LEFT JOIN last_review r ON r.order_id = o.order_id AND r.rn = 1;

-- name: mart_check
SELECT COUNT(*) AS rows_count, COUNT(DISTINCT order_id) AS unique_orders
FROM orders_mart;
