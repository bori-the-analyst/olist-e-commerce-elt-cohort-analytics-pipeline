-- PHASE 6: Cohort Retention Matrix, Monthly ARPU and Cumulative CLV Analytics. 
-- ['Stage 5' has provided foundation for objective analysis]
-- Dataset's last COMPLETE month is Aug 2018 (Sep 2018 is a partial month and is excluded).

/*    OBJECTIVE REMINDER:
* Cohort retention rate = (count of customer_unique_Id of cohort IN timeframe N) / (count of customer_unique_id IN initial cohort timeframe 0) * 100
	-- 	cohort creation based ON 1st ORDER timeframe.
* ARPU (cohort c, month n) = (Revenue of cohort c {in month n}) / (Initial size of cohort c)
* Cumulative CLV (cohort c, month n) = (Total revenue of cohort c {from month 0 through month n}) / (Initial size of cohort c)     */

-- 6.1 Cohort Retention (BI-ready long retention table)
	-- granular machine-readable retention trajectory of every acquisition cohort across each month. (WHY? Visualization tools strongly prefer long (unpivoted) tables).
WITH cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS initial_cohort_size
    FROM analytics.fct_customer_cohorts
    WHERE month_index = 0
    GROUP BY cohort_month
),
cohort_activity AS (
    SELECT cohort_month, month_index, COUNT(DISTINCT customer_unique_id) AS active_users
    FROM analytics.fct_customer_cohorts
    WHERE cohort_month + month_index::INT * INTERVAL '1 month' <= DATE '2018-08-01'
    GROUP BY cohort_month, month_index
)
SELECT
    a.cohort_month,
    s.initial_cohort_size,
    a.month_index,
    a.active_users,
    ROUND(100.0 * a.active_users / s.initial_cohort_size, 2) AS retention_percentage
FROM cohort_activity a
JOIN cohort_sizes s ON a.cohort_month = s.cohort_month
ORDER BY a.cohort_month, a.month_index;


-- 6.2 Pivoted Cohort Retention matrix (rows = cohort months, columns = M_0, M_1, ...) (Wide/Executive Format) (same as 6.1 but human-readable for even non-technical audience)
-- Offsets beyond the last complete month return NULL (not yet observable), not 0.
WITH cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS initial_size
    FROM analytics.fct_customer_cohorts
    WHERE month_index = 0
    GROUP BY cohort_month
),
activity AS (
    SELECT cohort_month, month_index, COUNT(DISTINCT customer_unique_id) AS active_users
    FROM analytics.fct_customer_cohorts
    GROUP BY cohort_month, month_index
),
data_end AS (
    SELECT DATE '2018-08-01' AS last_month  -- last complete month
)
SELECT
    s.cohort_month,
    s.initial_size,
    ROUND(100.0 * COALESCE(SUM(a.active_users) FILTER (WHERE a.month_index = 0), 0) / s.initial_size, 1) AS "M_0",
    CASE WHEN s.cohort_month + INTERVAL '1 month' <= e.last_month
         THEN ROUND(100.0 * COALESCE(SUM(a.active_users) FILTER (WHERE a.month_index = 1), 0) / s.initial_size, 1) END AS "M_1",
    CASE WHEN s.cohort_month + INTERVAL '2 month' <= e.last_month
         THEN ROUND(100.0 * COALESCE(SUM(a.active_users) FILTER (WHERE a.month_index = 2), 0) / s.initial_size, 1) END AS "M_2",
    CASE WHEN s.cohort_month + INTERVAL '3 month' <= e.last_month
         THEN ROUND(100.0 * COALESCE(SUM(a.active_users) FILTER (WHERE a.month_index = 3), 0) / s.initial_size, 1) END AS "M_3",
    CASE WHEN s.cohort_month + INTERVAL '6 month' <= e.last_month
         THEN ROUND(100.0 * COALESCE(SUM(a.active_users) FILTER (WHERE a.month_index = 6), 0) / s.initial_size, 1) END AS "M_6",
    CASE WHEN s.cohort_month + INTERVAL '12 month' <= e.last_month
         THEN ROUND(100.0 * COALESCE(SUM(a.active_users) FILTER (WHERE a.month_index = 12), 0) / s.initial_size, 1) END AS "M_12"
FROM cohort_sizes s
CROSS JOIN data_end e
LEFT JOIN activity a ON a.cohort_month = s.cohort_month
GROUP BY s.cohort_month, s.initial_size, e.last_month
ORDER BY s.cohort_month;


-- 6.3 Monthly ARPU and Cumulative CLV ()
/* ARPU (cohort c, month n)  = revenue of cohort c in month n / initial size of cohort c
   Cumulative CLV            = running sum of ARPU from M_0 through month n */
WITH monthly_metrics AS (
    SELECT
        cohort_month,
        month_index,
        COUNT(DISTINCT customer_unique_id) AS active_users,
        SUM(total_order_value) AS monthly_revenue
    FROM analytics.fct_customer_cohorts
    -- Exclude the partial final month (Sep 2018)
    WHERE cohort_month + month_index::INT * INTERVAL '1 month' <= DATE '2018-08-01'
    GROUP BY cohort_month, month_index
),
cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_unique_id) AS initial_size
    FROM analytics.fct_customer_cohorts
    WHERE month_index = 0
    GROUP BY cohort_month
)
SELECT
    m.cohort_month,
    s.initial_size,
    m.month_index,
    m.active_users,
    ROUND(m.monthly_revenue, 2) AS monthly_revenue,
    ROUND(m.monthly_revenue / s.initial_size, 2) AS monthly_arpu,
    ROUND(
        SUM(m.monthly_revenue / s.initial_size) OVER (
            PARTITION BY m.cohort_month
            ORDER BY m.month_index
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 2
    ) AS cumulative_clv
FROM monthly_metrics m
JOIN cohort_sizes s ON m.cohort_month = s.cohort_month
ORDER BY m.cohort_month, m.month_index;
