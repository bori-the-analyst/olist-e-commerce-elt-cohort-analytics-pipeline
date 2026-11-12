/* STAGE 5: ANALYTICS MART LAYER (base for Stage-6 Model Analysis)
This layer creates base for 'Stage 6' model analytics {Monthly Cohort Retention Grid (M_0, M_1, ..., M_n), and the Cumulative CLV & ARPU Model}
	'fct_customer_cohorts' table would serve as dimensional foundation (the "Grain") to bridge cleaned staging layer transactional data into human-centric cohort timelines (cohort_month and month_index).
 */

-- 5.1 Customer Cohort Model Table
	-- TO calculate cohort retention, we have to know for each customer, what their acquisiton month is.
	-- The business uses transactional customer_id values while tracking unique humans via customer_unique_id
	-- As such, Cohorts will be created on basis of month (timestamp) of very 1st purchased order. 
	-- Cohort TAble Attributes deliverables:		-- customer_unique_id, cohort_month, order_id, purchase_timestamp, order_month, total_order_value, month_index

-- 5.2 Create Analytics Schema (Bridging stg_customers, stg_order_items, stg_orders)
CREATE SCHEMA IF NOT EXISTS analytics;

-- 5.3. Customer Cohort Base Table (Physical Table / Intermediate Mart)
DROP TABLE IF EXISTS analytics.fct_customer_cohorts;

CREATE TABLE analytics.fct_customer_cohorts AS
	WITH customer_first_purchase AS (
	    -- Finding precise timestamp of each unique human customer's very first order
	    SELECT 
	        c.customer_unique_id,
	        MIN(o.purchase_timestamp) AS first_purchase_timestamp,
	        DATE_TRUNC('month', MIN(o.purchase_timestamp))::DATE AS cohort_month
	    FROM staging.stg_orders o
	    JOIN staging.stg_customers c ON o.customer_id = c.customer_id
	    GROUP BY c.customer_unique_id
	)	
SELECT 
    cfp.customer_unique_id,
    cfp.cohort_month,
    o.order_id,
    o.purchase_timestamp,
    DATE_TRUNC('month', o.purchase_timestamp)::DATE AS order_month,
    oi.total_order_value,
    -- Calculate the relative month index (M_0, M_1, M_2, etc.)
    (
        EXTRACT(YEAR FROM DATE_TRUNC('month', o.purchase_timestamp)) * 12 + EXTRACT(MONTH FROM DATE_TRUNC('month', o.purchase_timestamp))
    )
    	- 	-- subtracting distance in months between acquisition month (M_0) and subsequent purchase month (M_1, M_2, ..., M_N)
    (
        EXTRACT(YEAR FROM cfp.cohort_month) * 12 + EXTRACT(MONTH FROM cfp.cohort_month)
    ) AS month_index
FROM customer_first_purchase cfp
JOIN staging.stg_customers c ON cfp.customer_unique_id = c.customer_unique_id
JOIN staging.stg_orders o ON c.customer_id = o.customer_id
JOIN staging.stg_order_items oi ON o.order_id = oi.order_id;



-- 5.4 Quick view of created analytical cohort table 
SELECT * FROM analytics.fct_customer_cohorts fcc LIMIT 10;

-- 5.5 Quick check for customer count per acqusition & subsequent active months
SELECT month_index, count(DISTINCT customer_unique_id) UNIQUE_customers
FROM analytics.fct_customer_cohorts fcc
GROUP BY month_index
ORDER BY month_index ASC;
