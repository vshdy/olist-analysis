-- Повторные покупки. Ключевой момент: customer_id выдаётся на каждый заказ,
-- реальный человек - это customer_unique_id.

-- name: repeat_customers_naive
WITH clients AS (
    SELECT c.customer_unique_id, COUNT(o.order_id) AS orders
    FROM customers c
    LEFT JOIN orders o ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT COUNT(*) AS all_clients,
       COUNT(CASE WHEN orders > 1 THEN 1 END) AS repeat_clients,
       ROUND(100.0 * COUNT(CASE WHEN orders > 1 THEN 1 END) / COUNT(*), 2) AS repeat_pct
FROM clients;

-- name: repeat_customers_real
-- часть "повторных" заказов сделана в тот же день (разбитые корзины) - это не возвраты
WITH orders_lag AS (
    SELECT c.customer_unique_id,
           o.order_id,
           o.order_purchase_timestamp::date
             - LAG(o.order_purchase_timestamp::date) OVER (
                   PARTITION BY c.customer_unique_id
                   ORDER BY o.order_purchase_timestamp) AS days_since_prev
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
)
SELECT COUNT(CASE WHEN days_since_prev = 0 THEN 1 END)  AS same_day_orders,
       COUNT(CASE WHEN days_since_prev >= 1 THEN 1 END) AS real_returns,
       COUNT(DISTINCT CASE WHEN days_since_prev >= 1 THEN customer_unique_id END) AS real_repeat_customers,
       ROUND(100.0 * COUNT(DISTINCT CASE WHEN days_since_prev >= 1 THEN customer_unique_id END)
             / COUNT(DISTINCT customer_unique_id), 2) AS real_repeat_pct
FROM orders_lag;

-- name: days_to_return
-- для каждого настоящего возврата: сколько дней прошло с предыдущего заказа
WITH orders_lag AS (
    SELECT c.customer_unique_id,
           o.order_purchase_timestamp::date
             - LAG(o.order_purchase_timestamp::date) OVER (
                   PARTITION BY c.customer_unique_id
                   ORDER BY o.order_purchase_timestamp) AS days_since_prev
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
)
SELECT days_since_prev
FROM orders_lag
WHERE days_since_prev >= 1;

-- name: new_customers_by_month
-- новые клиенты (месяц первого заказа) против всех заказов месяца
WITH first_orders AS (
    SELECT c.customer_unique_id,
           o.order_purchase_timestamp,
           ROW_NUMBER() OVER (PARTITION BY c.customer_unique_id
                              ORDER BY o.order_purchase_timestamp ASC) AS rn
    FROM customers c
    JOIN orders o ON o.customer_id = c.customer_id
),
new_by_month AS (
    SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
           COUNT(*) AS new_customers
    FROM first_orders
    WHERE rn = 1
    GROUP BY 1
),
all_by_month AS (
    SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
           COUNT(*) AS all_orders
    FROM orders
    GROUP BY 1
)
SELECT a.month,
       a.all_orders,
       n.new_customers,
       ROUND(100.0 * n.new_customers / a.all_orders, 1) AS new_share_pct
FROM all_by_month a
JOIN new_by_month n ON n.month = a.month
WHERE a.month >= '2017-01-01' AND a.month < '2018-09-01'
ORDER BY a.month;
