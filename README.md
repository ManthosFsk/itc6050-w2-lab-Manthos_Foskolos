# Week 2 Lab: Data Modeling, Normalisation, and Optimisation

## Concept Checks & Deliverables

### Step 1: Conceptual Model
* **Question:** Why is `OrderItem` a separate entity? Why not just put a `product_id` field inside the `Order` table?
* **Answer:** If we placed `product_id` directly inside the `Order` table, each order would only be able to contain a single product. By creating `OrderItem` as a separate associative/join entity, we establish a many-to-many relationship between Orders and Products. This allows a single order to contain multiple different products, each with its own specific quantity and historical sale price.

### Step 2: Logical Model
* **Question:** Why does the logical model avoid database-specific types like PostgreSQL's `BIGINT` or `JSONB`?
* **Answer:** The logical model is intended to be vendor-neutral and independent of any specific Database Management System (DBMS). Its purpose is to map business requirements and data relationships clearly. By using generic data types (like `int`, `varchar`, `boolean`), the schema remains portable and can be easily reviewed by business stakeholders or mapped to any other relational database engine (e.g., MySQL, Oracle, SQL Server) without modifications.

### Step 3: Physical Schema
* **Question:** We used `ON DELETE CASCADE` for `address.customer_id`. Why would this be a dangerous or incorrect choice for `order_item.order_id` or `orders.customer_id`?
* **Answer:** Using `ON DELETE CASCADE` on transactional data like orders and order items is highly dangerous because deleting a customer or a product would automatically wipe out the entire related sales history. This completely destroys the company's financial records, accounting data, and audit trails. Instead, we use `ON DELETE RESTRICT` (or `ON DELETE NO ACTION`), which prevents the deletion of a customer or product if they are linked to existing orders, thereby preserving data integrity.

### Step 4: Fix - Normalisation
* **Question:** Which Normal Form(s) does the `orders_bad` table violate, and why?
* **Answer:** The `orders_bad` table violates both **2NF** and **3NF**:
  1. **It violates 2NF (Second Normal Form)** because it contains partial dependencies. The product attributes (`product_name` and `product_price`) depend entirely on `product_id`, which is only a part of the table's implicit composite key, rather than depending on the whole transaction.
  2. **It violates 3NF (Third Normal Form)** because it contains transitive dependencies. The customer attributes (`customer_name` and `customer_email`) depend directly on `customer_id`, which in turn depends on `order_id`. If a customer places multiple orders, their profile information is redundantly duplicated, introducing severe risks of update anomalies.