-- STAGE 4: PRODUCTION "STAGING" LAYER
/* 
Based on the exact anomalies, whitespace issues, and date structures uncovered during data profiling audit.
I will build three clean Staging Views in my staging schema.
	* Here, Views are adopted over Physical Tables, for real-time, virtual, and efficient staging. Further reducing and optimizing resource allocation on disk/cloud. 
These views act as the automated transformation engine—cleaning the data on the fly while keeping the raw original tables pristine and immutable.
*/

-- 4.1 Schema creation
CREATE SCHEMA IF NOT EXISTS staging;

-- 4.2 STAGING VIEWS

-- 4.2.1 Staging Customers View
-- Handling whitespaces, proper casing, and null mapping 
CREATE OR REPLACE VIEW staging.stg_customers AS
	SELECT
		TRIM(customer_id) AS customer_id,
		TRIM(customer_unique_id) AS customer_unique_id,
		TRIM(customer_zip_code_prefix) AS zip_code,
		INITCAP(TRIM(customer_city)) AS city,
		INITCAP(TRIM(customer_state)) AS state
	FROM raw.customers;

-- 4.2.2 Staging Orders View
-- Handling whitespaces, proper status casing, text to timestamp conversion, filtering out "cancelled" orders.
CREATE OR REPLACE VIEW staging.stg_orders AS
	SELECT
		TRIM(order_id) order_id,
		TRIM(customer_id) customer_id,
		LOWER(TRIM(order_status)) order_status,
		order_purchase_timestamp::TIMESTAMP AS purchase_timestamp,
		order_approved_at::TIMESTAMP AS approved_at,
		order_delivered_carrier_date::TIMESTAMP AS delivered_carrier_date,
		order_delivered_customer_date::TIMESTAMP AS delivered_customer_date,
		order_estimated_delivery_date::TIMESTAMP AS estimated_delivery_date
	FROM raw.orders
	WHERE lower(order_status) NOT IN ('cancelled', 'unavailable');

-- 4.2.3 Staging Order Items View
-- Casting prices/freight to numeric, aggregating line items to order-level monetary values
CREATE OR REPLACE VIEW staging.stg_order_items AS
SELECT 
    TRIM(order_id) AS order_id,
    COUNT(order_item_id) AS total_items_in_order,
    SUM(price::NUMERIC) AS total_goods_price,
    SUM(freight_value::NUMERIC) AS total_freight_value,
    SUM(price::NUMERIC + freight_value::NUMERIC) AS total_order_value
FROM raw.order_items
GROUP BY order_id;


-- Verifying staging schema and views are live
SELECT table_name
FROM information_schema.VIEWS
WHERE table_schema = 'staging';

-- Verifying staging views are returning clean data:
-- Test Customer Staging
SELECT * FROM staging.stg_customers LIMIT 5;

-- Test Orders Staging (Checking row counts post-cancellation filter)
SELECT order_status, COUNT(*) 
FROM staging.stg_orders 
GROUP BY order_status;

-- Test Order Items Staging
SELECT * FROM staging.stg_order_items LIMIT 5;



-- NEXT: STAGE 5: ANALYTICS MART LAYER
