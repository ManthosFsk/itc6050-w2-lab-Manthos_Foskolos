-- sql/04_indexing.sql
SET search_path TO shop;

-- Q1: Look up a customer by email
EXPLAIN ANALYZE
SELECT * FROM customer WHERE email = 'cust5000@example.com';

-- Q2: All orders for a given customer in date order
EXPLAIN ANALYZE
SELECT order_id, order_date, total FROM orders ORDER BY order_date DESC;

-- Q3: Top 10 products by revenue in the last 90 days
EXPLAIN ANALYZE
SELECT p.name, SUM(oi.quantity * oi.unit_price_at_sale) AS revenue
FROM order_item oi
JOIN orders o USING (order_id)
JOIN product p USING (product_id)
WHERE o.order_date >= NOW() - INTERVAL '90 days'
GROUP BY p.name
ORDER BY revenue DESC
LIMIT 10;