-- PHASE 2: REQUIREMENTS SCOPING AND MINIMUM VIABLE ATTRIBUTES --
-- Focus henceforth on Core Tables for business objective: 

/* Project Deliverables and required attributes:
Cohort Retention: ("Unique Active Customers in Period" N) / "Total Customers in Initial Cohort (Period 0)" X 100
1. Unique Customer ID
2. Acquisition timestamp / date
3. Transaction/Activity/Order timestamp

ARPU: ("Total Revenue Generated in Period " TR ) / ("Total Active Users in Period " TAU)
1. Unique Customer ID
2. Transaction/ACtivity/Order timestamp
3. Order sale/revenue

Gross Revenue-Based CLV : {Average Order Value (AOV)} X {Purchase Frequency Rate} X {Customer Lifespan}
1. Unique customer id
2. transaction/order/activity unique id
3. transaction date
4. order revenue

Overall Attributes needed:
Unique Customer ID,
First Purchase / Acquisition Date / Signup Date
Order Transaction ID
Transaction Date / Timestamp
Order Revenue / Sales
*/

-- STEP 1: Identifying attributes required for business objective.
-- 1.1 Unique Customer ID
SELECT COUNT(*) totalrows, COUNT(DISTINCT(customer_Id)) distinct_cust_id, COUNT(DISTINCT(customer_unique_Id)) distinct_cust_unq_id
FROM raw.customers c;

-- Identifying duplicate rows in customer_unique_id
-- Unique Customer ID = customer_id FROM raw.customers
SELECT customer_unique_Id "duplicate customer_unique_id", COUNT(customer_unique_Id) count
FROM customers c
GROUP BY customer_unique_Id
HAVING COUNT(customer_unique_Id) > 1;

-- 1.2 Customer Acquisition Date (Very first timestamp a customer placed order (firm commitment action/trigger) [excluding cancelled orders]:
-- Customer Acquisition Date = raw.orders.order_purchase_timestamp
SELECT 
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp::TIMESTAMP) AS first_purchase_timestamp
FROM raw.orders o
JOIN raw.customers c ON o.customer_id = c.customer_id
WHERE o.order_status <> 'canceled'
GROUP BY c.customer_unique_id;

-- 1.3 Order Transaction ID
-- Unique Order Transaction ID = order_id FROM raw.orders
SELECT order_id
FROM raw.orders o 

-- 1.4 Transaction Date
-- Customer Acquisition Date = order_purchase_timestamp FROM raw.orders
SELECT order_id, order_purchase_timestamp
FROM raw.orders;

-- 1.5 Order Revenue
-- Order Revenue = price + freight_value
SELECT 
	order_id,
	SUM(price::NUMERIC + freight_value::NUMERIC) AS total_order_revenue
FROM order_items oi 
GROUP BY ORDER_id;

/* STEP 2: 
 * Distinguishing between required tables and peripheral (surplus to requirements) tables relative to business objective (CLV, ARPU & Cohort Analysis).
 * Eliminating scope creep
*/
SELECT * FROM raw.customers; -- required
SELECT * FROM raw.orders; -- required
SELECT * FROM raw.order_items; -- required
SELECT * FROM raw.closed_deals; -- peripheral
SELECT * FROM raw.geolocation; -- peripheral
SELECT * FROM raw.mql; -- peripheral
SELECT * FROM raw.order_payments; -- peripheral
SELECT * FROM raw.products; -- periheral
SELECT * FROM raw.sellers; -- peripheral
SELECT * FROM raw.prod_cat_name_translation; -- peripheral
