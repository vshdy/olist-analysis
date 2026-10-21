-- Проверка качества данных перед анализом.

-- name: dq_overview
SELECT (SELECT COUNT(*) FROM orders)                              AS orders,
       (SELECT COUNT(DISTINCT customer_id) FROM customers)        AS customer_ids,
       (SELECT COUNT(DISTINCT customer_unique_id) FROM customers) AS unique_customers,
       (SELECT COUNT(*) FROM order_items)                         AS order_items,
       (SELECT COUNT(*) FROM order_reviews)                       AS reviews,
       (SELECT COUNT(*) FROM products)                            AS products,
       (SELECT MIN(order_purchase_timestamp) FROM orders)         AS first_order,
       (SELECT MAX(order_purchase_timestamp) FROM orders)         AS last_order;

-- name: dq_orders_without_items
-- 775 заказов без позиций в order_items, почти все unavailable / canceled
SELECT o.order_status, COUNT(*) AS orders
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY orders DESC;

-- name: dq_issues
-- остальные найденные проблемы одной таблицей
SELECT 'заказы без отзыва' AS issue, COUNT(*) AS cnt
FROM orders o
LEFT JOIN order_reviews r ON r.order_id = o.order_id
WHERE r.review_id IS NULL
UNION ALL
SELECT 'доставленные заказы без даты доставки', COUNT(*)
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL
UNION ALL
SELECT 'товары без категории', COUNT(*)
FROM products
WHERE product_category_name IS NULL
UNION ALL
SELECT 'заказы с несколькими отзывами', COUNT(*)
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) AS t;

-- name: dq_orders_by_month_all
-- полный период: видно неполные месяцы в начале (2016) и в конце (сентябрь-октябрь 2018)
SELECT DATE_TRUNC('month', order_purchase_timestamp)::date AS month,
       COUNT(*) AS orders
FROM orders
GROUP BY 1
ORDER BY 1;
