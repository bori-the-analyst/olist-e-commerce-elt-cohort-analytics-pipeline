/*
 * Project Title: E-Commerce Customer Retention & Cohort Analytics Engine
 * Dataset: Olist Brazilian E-Commerce Public Dataset
 * Primary Deliverables:
 * 	1. Staging & Analytics DDL Scripts: Reproducible, version-controlled table structures.
 * 	2. SQL Analytics Mart: Modular SQL views/models (01_staging, 02_intermediate, 03_marts).
 * 	3. Monthly Cohort Retention Grid: Distinct customer count and retention % matrix calculated purely in SQL ($M_0, M_1, \dots, M_n$).
 * 	4. Cohort Cumulative ARPU & CLV Model: Financial yield per acquisition vintage over time.
 * 	5. GitHub Production Repository: Structured with clean documentation, data contract, DDL, and executive business summary
 */

/* PHASE 1 - Database, Raw Schema & Tables Initialization and Ingestion*/

-- Verify 'olist_analytics' database does not exist.
SELECT datname
FROM pg_database
WHERE datname = 'olist_analytics'

-- Create 'olist_analytics' database
CREATE DATABASE olist_analytics;

-- Create isolated schemas for raw staging and transformed analytics marts
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS analytics;

-- Utilized PowerShell to peek and capture column headers
-- i.e. Get-Content "folder_path\olist_customers_dataset.csv" -Head 10

-- RAW Schema tables' creation
CREATE TABLE raw.closed_deals (
	mql_id TEXT,
	seller_id TEXT,
	sdr_id TEXT,
	sr_id TEXT,
	won_date TEXT,
	business_segment TEXT,
	lead_type TEXT,
	lead_behaviour_profile TEXT,
	has_company TEXT,
	has_gtin TEXT,
	average_stock TEXT,
	business_type TEXT,
	declared_product_catalog_size TEXT,
	declared_monthly_revenue TEXT
);

CREATE TABLE raw.customers (
	customer_id TEXT,
	customer_unique_id TEXT,
	customer_zip_code_prefix TEXT,
	customer_city TEXT,
	customer_state TEXT
);
	
CREATE TABLE raw.geolocation (
	geolocation_zip_code_prefix TEXT,
	geolocation_lat TEXT,
	geolocation_lng TEXT,
	geolocation_city TEXT,
	geolocation_state TEXT
);

CREATE TABLE raw.mql (
	mql_id TEXT,
	first_contact_date TEXT,
	landing_page_id TEXT,
	origin TEXT
);

CREATE TABLE raw.order_items(
	order_id TEXT,
	order_item_id TEXT,
	product_id TEXT,
	seller_id TEXT,
	shipping_limit_date TEXT,
	price TEXT,
	freight_value TEXT
);

CREATE TABLE raw.order_payments(
	order_id TEXT,
	payment_sequential TEXT,
	payment_type TEXT,
	payment_installments TEXT,
	payment_value TEXT
);

CREATE TABLE raw.order_reviews(
review_id TEXT,
order_id TEXT,
review_score TEXT,
review_comment_title TEXT,
review_comment_message TEXT,
review_creation_date TEXT,
review_answer_timestamp TEXT
);

CREATE TABLE raw.orders(
order_id TEXT,
customer_id TEXT,
order_status TEXT,
order_purchase_timestamp TEXT,
order_approved_at TEXT,
order_delivered_carrier_date TEXT,
order_delivered_customer_date TEXT,
order_estimated_delivery_date TEXT
);

CREATE TABLE raw.products(
product_id TEXT,
product_category_name TEXT,
product_name_lenght TEXT,
product_description_lenght TEXT,
product_photos_qty TEXT,
product_weight_g TEXT,
product_length_cm TEXT,
product_height_cm TEXT,
product_width_cm TEXT
);

CREATE TABLE raw.sellers(
seller_id TEXT,
seller_zip_code_prefix TEXT,
seller_city TEXT,
seller_state TEXT
);

CREATE TABLE raw.prod_cat_name_translation(
product_category_name TEXT,
product_category_name_english TEXT
);


-- Verifying all raw tables exist in our RAW schema
SELECT table_name
FROM information_schema.tables s
WHERE table_schema = 'raw'



-- RAW TABLE DATA INGESTION
-- Complete Raw Table Ingestion performed using Powershell.
	/* i.e. 
	 * 		\copy raw.raw_customers 
			FROM 'folder_path/olist_customers_dataset.csv' 
			WITH (FORMAT csv, HEADER true, DELIMITER ',', ENCODING 'UTF8');
	*/

-- Check for 100% data ingestion by PowerShell
SELECT * FROM raw.closed_deals;
SELECT * FROM raw.customers;
SELECT * FROM raw.geolocation;
SELECT * FROM raw.mql;
SELECT * FROM raw.order_items;
SELECT * FROM raw.order_payments;
SELECT * FROM raw.orders;
SELECT * FROM raw.products;
SELECT * FROM raw.sellers;
SELECT * FROM raw.prod_cat_name_translation;
