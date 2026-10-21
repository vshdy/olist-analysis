-- Динамика заказов и выручки. Период анализа: январь 2017 - август 2018.

-- name: monthly_orders_growth
WITH monthly AS (
    SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
           COUNT(*) AS orders
    FROM orders
    WHERE order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
    GROUP BY 1
)
SELECT month,
       orders,
       LAG(orders) OVER (ORDER BY month) AS prev_orders,
       ROUND(100.0 * (orders - LAG(orders) OVER (ORDER BY month))
             / LAG(orders) OVER (ORDER BY month), 1) AS growth_pct
FROM monthly
ORDER BY month;

-- name: monthly_revenue_cumulative
-- выручка = сумма price доставленных заказов
WITH monthly AS (
    SELECT DATE_TRUNC('month', o.order_purchase_timestamp)::date AS month,
           SUM(oi.price) AS revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY 1
)
SELECT month,
       ROUND(revenue) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY month)) AS cumulative_revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS month_share_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY month) / SUM(revenue) OVER (), 1) AS cumulative_share_pct
FROM monthly
ORDER BY month;

-- name: avg_check
-- средний чек и медиана (только товары, без доставки)
WITH order_totals AS (
    SELECT order_id, SUM(price) AS total
    FROM order_items
    GROUP BY order_id
)
SELECT ROUND(AVG(total), 2) AS avg_check,
       ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total)::numeric, 2) AS median_check,
       ROUND(100.0 * COUNT(CASE WHEN total > (SELECT AVG(total) FROM order_totals) THEN 1 END)
             / COUNT(*), 1) AS above_avg_pct
FROM order_totals;

-- name: weekday_orders
SELECT EXTRACT(ISODOW FROM order_purchase_timestamp) AS weekday_num,
       TO_CHAR(order_purchase_timestamp, 'FMDay')     AS weekday,
       COUNT(*) AS orders
FROM orders
GROUP BY 1, 2
ORDER BY 1;
