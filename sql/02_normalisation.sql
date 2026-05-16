SET search_path TO shop;

-- 1. Δημιουργία του "κακού" μη-κανονικοποιημένου πίνακα
CREATE TABLE orders_bad (
    order_id INT,
    customer_id INT,
    customer_name VARCHAR(100),
    customer_email VARCHAR(100),
    order_date DATE,
    product_id INT,
    product_name VARCHAR(100),
    product_price NUMERIC(10,2),
    quantity INT
);

-- 2. Εισαγωγή των προβληματικών δεδομένων από το PDF
INSERT INTO orders_bad VALUES 
(1001, 1, 'Alice Smith', 'alice@email.com', '2024-03-01', 501, 'Laptop', 999.99, 1),
(1001, 1, 'Alice Smith', 'alice@email.com', '2024-03-01', 502, 'Mouse', 25.00, 2),
(1002, 2, 'Bob Jones', 'bob@email.com', '2024-03-02', 501, 'Laptop', 999.99, 1),
(1003, 1, 'Alice Smith', 'alice@email.com', '2024-03-03', 503, 'Keyboard', 45.00, 1);


-- 3. Η ΔΙΟΡΘΩΣΗ (Μεταφορά σε 3NF στους καθαρούς μας πίνακες)

-- Α) Μεταφέρουμε τους μοναδικούς πελάτες στον πίνακα customer
INSERT INTO customer (email, first_name, last_name)
SELECT DISTINCT 
    customer_email, 
    split_part(customer_name, ' ', 1), -- Παίρνει το πρώτο όνομα
    split_part(customer_name, ' ', 2)  -- Παίρνει το επίθετο
FROM orders_bad
ON CONFLICT (email) DO NOTHING;

-- Β) Μεταφέρουμε τις μοναδικές κατηγορίες και προϊόντα
INSERT INTO category (name) VALUES ('General Electronics') ON CONFLICT DO NOTHING;

INSERT INTO product (category_id, name, unit_price)
SELECT DISTINCT 
    1, -- ID της κατηγορίας που μόλις φτιάξαμε
    product_name, 
    product_price
FROM orders_bad;

-- Γ) Μεταφέρουμε τις μοναδικές κεφαλίδες παραγγελιών (Orders)
INSERT INTO orders (customer_id, order_date, status, total)
SELECT DISTINCT 
    c.customer_id, 
    ob.order_date::timestamptz, 
    'Completed', 
    0 -- Θα υπολογιστεί μετά
FROM orders_bad ob
JOIN customer c ON c.email = ob.customer_email;

-- Δ) Μεταφέρουμε τις γραμμές των προϊόντων (Order Items)
INSERT INTO order_item (order_id, product_id, quantity, unit_price_at_sale)
SELECT 
    o.order_id, 
    p.product_id, 
    ob.quantity, 
    ob.product_price
FROM orders_bad ob
JOIN product p ON p.name = ob.product_name
-- Επειδή στον orders_bad είχαμε δικά μας IDs (1001, 1002), αλλά στους νέους πίνακες 
-- η Postgres έβαλε αυτόματα δικά της (1, 2, 3), κάνουμε join με την ημερομηνία για να βρούμε ποιο αντιστοιχεί πού
JOIN orders o ON o.order_date::date = ob.order_date;

-- Ε) Ενημερώνουμε τα σύνολα (total) στον πίνακα orders με βάση τα order_items
UPDATE orders o
SET total = (
    SELECT SUM(quantity * unit_price_at_sale)
    FROM order_item oi
    WHERE oi.order_id = o.order_id
);