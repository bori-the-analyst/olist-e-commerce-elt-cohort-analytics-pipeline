# Olist E-Commerce ELT Pipeline & Cohort Analytics Platform

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13%2B-blue?style=for-the-badge&logo=postgresql&logoColor=white)
![Architecture](https://img.shields.io/badge/Architecture-ELT-orange?style=for-the-badge)
![SQL](https://img.shields.io/badge/SQL-Advanced%20Analytics-green?style=for-the-badge&logo=postgresql&logoColor=white)
![Domain](https://img.shields.io/badge/Domain-E--Commerce%20%26%20CLV-purple?style=for-the-badge)

An end-to-end **Extract, Load, Transform (ELT)** pipeline and analytics engineering project built in PostgreSQL on Brazilian e-commerce data from Olist (100k+ orders).

It demonstrates a layered data warehouse design, a custom 4-pillar data profiling audit, virtual staging views, entity resolution, and dimensional modeling to produce **Monthly Customer Cohort Retention Grids** and **Cumulative Revenue-Based CLV (Customer Lifetime Value) & ARPU Models**.

---

## Table of Contents

- [Key Achievements](#key-achievements)
- [Pipeline Architecture](#pipeline-architecture)
- [Warehouse Schema Design](#warehouse-schema-design)
- [Data Profiling & Quality Audit](#data-profiling--quality-audit-4-pillar-framework)
- [Analytical Deliverables](#analytical-deliverables)
- [Repository Structure](#repository-structure)
- [Sample Output](#sample-output)
- [How to Run](#how-to-run)
- [Tech Stack & Skills](#tech-stack--skills)

---

## Key Achievements

- **Layered ELT architecture:** Designed a 3-tier warehouse (`raw_landing` → `staging` → `analytics`) that separates immutable raw ingestion from transformation logic and analytical reporting.
- **Custom data profiling audit:** Built a 4-pillar framework (Volume/Grain, Quality Dimensions, Entity Resolution, Temporal Sequence) to detect nulls, whitespace, referential breaks, and date violations.
- **Dynamic staging views:** Performed type casting, regex-based string sanitization, and quality filtering (e.g., removing canceled/unavailable orders) on read, with zero storage duplication.
- **Entity resolution:** Resolved the split between the transactional key (`customer_id`) and the persistent human entity (`customer_unique_id`), preventing falsely near-zero retention.
- **Cohort & monetization modeling:** Used window functions and relative month-index math to compute retention grids (M₀ to Mₙ) and cumulative ARPU curves.

---

## Pipeline Architecture

Raw CSV datasets are ingested untouched, cleaned dynamically through views, and materialized into analytical marts.

```text
┌──────────────────────────────────┐
│     RAW LANDING LAYER (raw)      │  <- Immutable TEXT-only CSV bulk load
└────────────────┬─────────────────┘
                 │
                 ▼  Dynamic SELECT transformations, type casting, cleaning
┌──────────────────────────────────┐
│      STAGING LAYER (staging)     │  <- Virtual views (TRIM, UPPER, CAST, filters)
└────────────────┬─────────────────┘
                 │
                 ▼  Entity resolution & dimensional modeling
┌──────────────────────────────────┐
│    ANALYTICS MARTS (analytics)   │  <- Fact tables & pivoted cohort/CLV models
└──────────────────────────────────┘
```

---

## Warehouse Schema Design

### 1. `raw` (Landing Schema)

- **Design:** All columns are defined as `TEXT` during bulk copy to guarantee zero load failures and preserve raw operational history.
- **Scope:** Ingested all 11 Olist tables, then deliberately scoped analysis down to 3 core operational tables (`customers`, `orders`, `order_items`) based on business requirement mapping.

### 2. `staging` (Transformation Layer)

- **Design:** Implemented as virtual **views**, so transformations run on read and no data is duplicated.

| View | Key Operations |
|------|----------------|
| `stg_customers` | Strips whitespace (`TRIM`), standardizes capitalization (`INITCAP`/`UPPER`), maps geography. |
| `stg_orders` | Casts string timestamps to `TIMESTAMP`, standardizes order status text, filters out non-fulfilled states (canceled, unavailable). |
| `stg_order_items` | Casts monetary strings to `NUMERIC(10,2)` to avoid floating-point errors; aggregates item prices and freight values to order-level totals. |

### 3. `analytics` (Marts Layer)

- **`fct_customer_cohorts`:** Physical base fact table bridging customers and orders. It calculates each unique customer's acquisition month (M₀) and computes the relative month index (M₀, M₁, …, Mₙ) for every transaction using year/month offset logic.

---

## Data Profiling & Quality Audit (4-Pillar Framework)

Before building the staging views, a full audit was run on the raw layer.

| Pillar | Focus | What Was Verified |
|--------|-------|-------------------|
| **1. Structural & Volume** | Grain verification | Primary key uniqueness for `customers` (`customer_id`) and `orders` (`order_id`); composite grain for `order_items` (`order_id` + `order_item_id`). |
| **2. Quality Dimensions** | Integrity & validity | Zero orphaned orders via `LEFT JOIN` checks against `customers`; no negative/zero anomalies in prices and freight (`price > 0`); order status distribution audited to isolate non-revenue statuses. |
| **3. Entity Resolution** | Identity matching | `customer_id` is a transient key (one per order), while `customer_unique_id` is the true human entity. Matching on `customer_unique_id` is mandatory for tracking repeat purchases. |
| **4. Temporal Boundary** | Date logic | Verified global date ranges and the sequence constraint `order_delivered_customer_date >= order_purchase_timestamp`. |

---

## Analytical Deliverables

### Deliverable 1: Monthly Cohort Retention Grid

Counts distinct active customers (`customer_unique_id`) across purchase-month offsets relative to their initial cohort month (M₀).

$$
\text{Retention Rate}_N = \frac{\text{Unique Active Customers in Period } N}{\text{Total Customers in Initial Cohort (Period 0)}} \times 100
$$

**Period definition:** Period 0 is the acquisition month (index 0). Periods 1, 2, … are subsequent monthly intervals.

### Deliverable 2: Cumulative ARPU & CLV Model

Normalizes monthly revenue against initial cohort size (M₀ baseline users) and computes running cumulative revenue per customer over time using SQL window frames.

$$
\text{ARPU} = \frac{\text{Total Revenue Generated in Period } R}{\text{Total Active Users in Period } U}
$$

$$
\text{CLV} = \text{Average Order Value (AOV)} \times \text{Purchase Frequency Rate} \times \text{Average Customer Lifespan}
$$

> **Implemented (simplified historical CLV):** the running sum of revenue generated per unique customer across historical transaction timestamps.

---

## Repository Structure

```text
olist-e-commerce-elt-pipeline/
│
├── README.md                                                   # Project documentation
├── 01_raw_landing/
│   └── 01_create_raw_schema.sql                                # Schema DDLs and raw table definitions
├── 02_requirements_scoping_and_minimum_viable_attributes/
│   └── 02_requirements_scoping_and_mva.sql                     # Scope definition to prevent scope creep
├── 03_data_profiling/
│   └── 03_data_profiling_audit.sql                             # 4-pillar quality audit & diagnostics
├── 04_staging_layer/
│   └── 04_staging_views.sql                                    # Cleaning, casting, and transformation views
├── 05_analytics_marts/
│   └── 05_fct_customer_cohorts.sql                             # Entity resolution & cohort fact table
└── 06_clv_arpu_models/
    └── 06_cohort_retention_matrix_and_cumulative_arpu_clv.sql  # Retention matrix, pivot logic, cumulative ARPU/CLV
```

---

## Sample Output

Pivoted cohort retention grid (%):

```text
cohort_month | initial_size |  M_0   |  M_1  |  M_2  |  M_3  |  M_6  | M_12
-------------+--------------+--------+-------+-------+-------+-------+------
 2017-01-01  |          747 | 100.0% |  0.4% |  0.3% |  0.1% |  0.4% | 0.1%
 2017-02-01  |         1641 | 100.0% |  0.2% |  0.3% |  0.1% |  0.1% | 0.2%
 2017-03-01  |         2547 | 100.0% |  0.5% |  0.3% |  0.4% |  0.4% | 0.2%
```

---

## How to Run

### Prerequisites

- PostgreSQL 13+
- A SQL client (DBeaver, pgAdmin, or `psql`)
- The [Olist Brazilian E-Commerce Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) from Kaggle

### Execution Flow

1. Run `01_create_raw_schema.sql` to create the landing tables, then bulk load the raw CSVs.
2. Run `02_requirements_scoping_and_mva.sql` to establish scope boundaries.
3. Run `03_data_profiling_audit.sql` for the 4-pillar quality diagnostic.
4. Run `04_staging_views.sql` to create the staging views.
5. Run `05_fct_customer_cohorts.sql` to build the cohort fact table.
6. Run `06_cohort_retention_matrix_and_cumulative_arpu_clv.sql` for the retention matrix and cumulative ARPU/CLV queries.

---

## Tech Stack & Skills

- **Database engine:** PostgreSQL
- **Architecture patterns:** ELT (Extract, Load, Transform), dimensional data modeling
- **Advanced SQL:** CTEs, window functions (`SUM() OVER`), date arithmetic (`DATE_TRUNC`, year/month offsets), string sanitization and regex validation (`SIMILAR TO`, `~`), conditional aggregation (`CASE WHEN` pivoting)
