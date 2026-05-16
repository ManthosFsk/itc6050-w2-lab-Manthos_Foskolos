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

## Step 6: Indexes & EXPLAIN ANALYZE

### 6a & 6b — Performance Execution Times Side-by-Side

| Query | Baseline (No Extra Indexes) | Post-Indexing (With New Indexes) | Query Plan Change |
| :--- | :--- | :--- | :--- |
| **Q1 (Customer by Email)** | 0.175 ms | 0.121 ms | Remained `Index Scan` due to original implicit UNIQUE constraint. |
| **Q2 (Orders Sorted by Date)** | 127.464 ms | 104.463 ms | Changed from `Seq Scan + Disk Sort` to `Index Scan Backward`. |
| **Q3 (Top 10 Products/Revenue)** | 205.059 ms | 168.025 ms | Changed `Seq Scan` on orders to `Bitmap Index Scan`. |

---

### 6c — Reflection Answers

#### 1. Which query saw the biggest speed-up? Why?
Query 2 and Query 3 saw notable execution time drops and significant architectural improvements. Query 2 achieved the most critical structural optimization because it completely eliminated a heavy on-disk sort operation (`external merge Disk: 3240kB`) by utilizing the pre-sorted B-Tree structure of the index to fetch rows directly in the requested order.

#### 2. Look at Q2's plan — did Postgres also use the index for ordering, or did it sort separately? How can you tell from the plan?
PostgreSQL used the index directly for ordering and did not sort separately. We can tell because the explicit `Sort` node and `Sort Method` lines completely vanished from the post-indexing plan. Instead, the top-level node became `Index Scan Backward using idx_orders_date`, proving that Postgres walked through the B-Tree index in reverse to satisfy the `ORDER BY order_date DESC` clause without any additional computational sorting.

#### 3. We added `idx_order_item_product` but never queried by `product_id` alone in Q1–Q3. Why is it still useful?
Even though we didn't query by `product_id` standalone, this index is vital for optimizing relational Joins. In Query 3, we join `order_item` with the `product` table using `product_id`. Having an index on the Foreign Key allows PostgreSQL to perform rapid hash lookups and index-driven matching between the two tables, instead of being forced to sequentially scan the large `order_item` table.

#### 4. Cost of indexes: what trade-off did we make by adding all these indexes? Name two operations that are now slightly slower.
The trade-off of adding indexes is increased disk space utilization and slower write throughput. Every time data changes, the database must keep the indexes updated. Two operations that are now slightly slower are:
* **`INSERT`:** New records require calculating and writing new nodes into multiple B-Tree index files.
* **`UPDATE`:** Modifying indexed columns (like `order_date` or `email`) forces the database to relocate index pointers.


---

## 💪 Stretch Challenges

### Challenge 1: Partial Index
To demonstrate the efficiency of partial indexes, two indexes were created and compared based on their storage size:
1. A full index tracking `order_date` across all rows (`idx_orders_date_full`).
2. A partial index tracking `order_date` only for rows `WHERE status = 'paid'` (`idx_orders_date_partial`).

#### Storage Comparison Results (`\di+` Output):
* **Full Index Size (`idx_orders_date_full`):** 2208 kB
* **Partial Index Size (`idx_orders_date_partial`):** 456 kB

#### Proof of Efficiency:
The partial index is roughly **5 times smaller** than the full index. Because the synthetic data distributes statuses evenly across 5 distinct values, filtering by `status = 'paid'` allows PostgreSQL to index only ~20% of the total records (the paid ones). This drastically reduces disk I/O, saves storage space, and keeps the index lean and highly performant in memory-constrained environments.

### Challenge 2: Composite Ordering
A multi-column composite index was created to handle both filtering and sorting structures efficiently using the columns: customer_id, status, and order_date DESC.

'''CREATE INDEX idx_composite_cust_status_date ON orders (customer_id, status, order_date DESC);΄΄΄

#### Query Execution Verification:
When running a query filtered by customer_id = 5000 AND status = 'paid' and ordered by order_date DESC, PostgreSQL utilized the newly created composite index:

* **Node Used:** Bitmap Index Scan on idx_composite_cust_status_date
* **Rows Retrieved:** 4 rows
* **Execution Time:** 0.225 ms

#### Why it is efficient:
Instead of creating multiple separate indexes for each column—which would increase write overhead during updates—this single composite index addresses complex multi-column predicates. It satisfies point lookups on customer_id and status while simultaneously positioning the database to optimize ordering constraints.

### Challenge 4: Find a Dead Index

By querying the PostgreSQL internal statistics view pg_stat_user_indexes, the usage of all custom indexes was analyzed to find unused locations using the following query:

SELECT indexrelname, idx_scan FROM pg_stat_user_indexes WHERE schemaname = 'shop';

#### Verification & Identification:
* The index **idx_orders_date_full** showed an idx_scan value of **0**.
* **Reason:** This index was created during Challenge 1 purely for storage size comparison purposes. Since the production application and our lab queries either use the main idx_orders_date or the highly specialized partial/composite indexes, this full index remains completely untouched by the query planner.

#### Clean-up Action:
To eliminate unnecessary disk storage (saving 2208 kB) and remove redundant write overhead during INSERT or UPDATE operations, the dead index was officially dropped from the schema using the command: DROP INDEX idx_orders_date_full;