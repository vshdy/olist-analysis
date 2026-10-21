-- Концентрация выручки по продавцам (правило Парето).

-- name: sellers_pareto_curve
WITH sellers AS (
    SELECT oi.seller_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY oi.seller_id
)
SELECT seller_id,
       revenue,
       ROW_NUMBER() OVER (ORDER BY revenue DESC) AS seller_rank,
       ROUND(100.0 * ROW_NUMBER() OVER (ORDER BY revenue DESC) / COUNT(*) OVER (), 2) AS sellers_pct,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(revenue) OVER (), 2) AS cumulative_revenue_pct
FROM sellers
ORDER BY seller_rank;

-- name: sellers_pareto_summary
WITH sellers AS (
    SELECT oi.seller_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN orders o ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
    GROUP BY oi.seller_id
),
cum AS (
    SELECT seller_id,
           100.0 * SUM(revenue) OVER (ORDER BY revenue DESC
                                      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
                 / SUM(revenue) OVER () AS pct
    FROM sellers
)
SELECT COUNT(*) AS all_sellers,
       COUNT(CASE WHEN pct < 80 THEN 1 END) AS sellers_for_80pct,
       ROUND(100.0 * COUNT(CASE WHEN pct < 80 THEN 1 END) / COUNT(*), 1) AS sellers_for_80pct_share
FROM cum;
