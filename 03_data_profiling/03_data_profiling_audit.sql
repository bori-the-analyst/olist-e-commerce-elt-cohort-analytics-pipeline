-- ============== PHASE 3: Data Profiling and Quality Assurance Audit ==========--

-- Focus henceforth on Core Tables for business objective: raw.customers, raw.orders, raw.order_items
/* Core attributes:
A. Cohort Retention: ("Unique Active Customers in Period N") / "Total Customers in Initial Cohort (Period 0)" X 100
	1. Unique Customer ID
	2. Acquisition timestamp / date
	3. Transaction/Activity/Order timestamp

B. Cumulative CLV [Revenue-based] (cohort c, month n) = (Total revenue of cohort c from month 0 through month n) / (Initial size of cohort c)
		-- The classical formula (AOV × Purchase Frequency × Customer Lifespan) is a forward-looking estimate and is not what this model computes.
	1. Unique customer id
	2. transaction/order/activity unique id
	3. transaction date
	4. order revenue

C. ARPU: ARPU (cohort c, month n) = (Revenue of cohort c in month n) / (Initial size of cohort c)
	1. Unique Customer ID
	2. Transaction/ACtivity/Order timestamp
	3. Order sale/revenue

Necessary attributes and source:
-- Unique Customer ID = customer_id FROM raw.customers
-- Customer Acquisition Date = order_purchase_timestamp FROM raw.orders
-- Unique Order Transaction ID = order_id FROM raw.orders
-- Transaction Date = order_purchase_timestamp FROM raw.orders
-- Order Revenue = (price + freight_value) FROM order_items

Necessary tables:
raw.customers, raw.orders, raw.order_items
*/

-- 3.1 PILLAR 1: Structure & Volume Profiling (Shape Audit):
-- 3.1.1 Row Volume Check
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM raw.customers
UNION ALL
SELECT 'orders', COUNT(*) FROM raw.orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM raw.order_items;

-- 3.1.2 Grain Definition & Primary Key Verification
-- If distinct keys match total rows, the table is uniquely keyed at that grain.
-- "What does one single row represent?"

-- Here, customer_id is the transactional/session key for the customer per transaction; whilst customer_unique_id is the non-changing id for the customer.
SELECT 
    (SELECT COUNT(*) FROM raw.customers) AS cust_total,
    (SELECT COUNT(DISTINCT customer_id) FROM raw.customers) AS distinct_customer_ids, -- PRIMARY KEY
    (SELECT COUNT(DISTINCT customer_unique_id) FROM raw.customers) AS distinct_unique_humans;

SELECT 
    (SELECT COUNT(*) FROM raw.orders) AS orders_total,
    (SELECT COUNT(DISTINCT order_id) FROM raw.orders) AS distinct_order_ids; -- PRIMARY KEY

SELECT 
    (SELECT COUNT(*) FROM raw.order_items) AS items_total,
    (SELECT COUNT(DISTINCT order_id) FROM raw.order_items) AS orders_with_items,
    -- Composite key check for order_items grain
    (SELECT COUNT(DISTINCT CONCAT(order_id, '_', order_item_id)) FROM raw.order_items) AS distinct_line_items; -- COMPOSITE KEY



-- 3.2 PILLAR 2: Data Quality Dimensions Audit:
-- *Objective: Hunt for nulls, invalid categoricals, broken referential integrity, and negative values
		
    -- 3.2.1 Completeness: Check for NULLs and blanks in critical columns
SELECT 
    COUNT(*) - COUNT(customer_id) AS null_customer_ids,
    	(SELECT COUNT(TRIM(customer_id)) FROM raw.customers WHERE customer_id = '') blank_customer_ids,
    COUNT(*) - COUNT(customer_unique_id) AS null_unique_ids,
    	(SELECT COUNT(TRIM(customer_unique_id)) FROM raw.customers WHERE customer_unique_id = '') blank_customer_unique_ids
FROM raw.customers;

SELECT
	COUNT(*) - COUNT(order_id) AS null_order_ids,
    	(SELECT COUNT(TRIM(order_id)) FROM raw.orders WHERE order_id = '') blank_order_ids,
	COUNT(*) - COUNT(order_purchase_timestamp) AS null_order_timestamps,
    	(SELECT COUNT(TRIM(order_purchase_timestamp)) FROM raw.orders WHERE order_purchase_timestamp = '') blank_order_timestamps
FROM raw.orders;

SELECT
	COUNT(*) - COUNT(price) AS null_prices,
    	(SELECT COUNT(TRIM(price)) FROM raw.order_items WHERE price = '') blank_prices,
	COUNT(*) - COUNT(freight_value) AS null_freight_values,
    	(SELECT COUNT(TRIM(freight_value)) FROM raw.order_items WHERE freight_value = '') blank_freight_values
FROM raw.order_items;


	-- 3.2.2 Uniqueness: Duplicate primary keys or unexpected entity duplication.
SELECT CUSTOMER_id, COUNT(*) FROM raw.customers GROUP BY CUSTOMER_id HAVING COUNT(*) > 1;
SELECT order_id, COUNT(*) FROM raw.orders GROUP BY ORDER_id HAVING COUNT(*) > 1;
SELECT COUNT(CONCAT(order_id, '_', order_item_id)) "order_Id & item_Id", COUNT(*) FROM raw.order_items GROUP BY CONCAT(order_id, '_', order_item_id) HAVING COUNT(*) > 1;

	-- 3.2.3. Validity: What order status cateogries exist in the raw data, and ensuring statuses are valid?
SELECT
	order_status,
	COUNT(*) AS status_count,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 3) status_distribution_prcnt
FROM raw.orders
GROUP BY order_status
ORDER BY status_distribution_prcnt DESC;

	-- 3.2.4 Consistency / Referential Integrity: Are there orders belonging to non-existent customers?
-- Exploring potential data story contradictions
--  Every single order must be tied to a living, breathing customer record
SELECT COUNT(o.order_id) AS orphan_orders_count
FROM raw.orders o
LEFT JOIN raw.customers c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

/*
SELECT COUNT(c.customer_id) -- COUNT(o.customer_id) AS orphan_orders_count
FROM raw.customers c
LEFT JOIN raw.orders o   
	ON c.customer_id = o.customer_id
*/

	-- 3.2.5. Accuracy: Check for accurate and valid, non-negative or zero prices/freight in order_items
	-- Check for if all timestamps are acceptable
SELECT COUNT(*) table_row_count, COUNT(o.order_purchase_timestamp) valid_timestamps
FROM raw.orders o 
WHERE o.order_purchase_timestamp SIMILAR TO '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}';

	-- Check for if all prices and freight_values are acceptable
SELECT count(*) table_row_count, COUNT(price) valid_price, COUNT(freight_value) valid_freight FROM raw.ORDER_items
WHERE (price ~ '^\d+\.\d{2}$' AND freight_value ~ '^\d+\.\d{2}$') AND (price::NUMERIC > 0 AND freight_value::NUMERIC > 0)


	-- 3.2.6 Timeliness/Currency
	-- Order timestamps matching reality.
	-- (SKIPPED to PILLAR 4)


-- 3.3 PILLAR 3: Granularity & Entity Resolution Audit:
-- Table Relationship mappings and Table Key 
-- Analyze order frequency per true unique customer
-- how many orders a single human (customer_unique_id) places on average.
SELECT c.customer_unique_id, count(o.*) total_orders
FROM raw.customers c 
JOIN raw.orders o
ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_Id
ORDER BY total_orders DESC
;

-- 3.4 PILLAR 4: Temporal and Range Profiling
-- Date Boundary Inspection (When does transactional data start and end?)
SELECT 
    MIN(order_purchase_timestamp) AS earliest_order,
    MAX(order_purchase_timestamp) AS latest_order,
    MAX(order_purchase_timestamp::DATE) - MIN(order_purchase_timestamp::DATE) total_order_period_days
FROM raw.orders;

-- 2. Timeliness / Logical Sequence Check: 
-- Does delivery date ever occur BEFORE purchase date?
SELECT COUNT(*) AS timeline_violations
FROM raw.orders
WHERE order_delivered_customer_date::TIMESTAMP < order_purchase_timestamp::TIMESTAMP;



/*
PHASE 3 SUMMARY:
	1. GRAIN CONFRIMATION: 
	Verified that customers are keyed by customer_id, orders by order_id, and order_items by the composite key (order_id + order_item_id).

	2. ROBUSTNESS TO DATA CORRUPTION:
	Quantified nulls, blank strings, and structural anomalies before they could pollute future analytical marts.
	
	3. BUSINESS LOGIC VALIDATION:
	Checked for orphan orders, zero/negative pricing anomalies, and chronological timeline violations (like delivery dates preceding purchase dates).
	
	4. ENTITY RESOLUTION SHOWCASE:
	Mapped out customer purchase frequencies via customer_unique_id
*/
