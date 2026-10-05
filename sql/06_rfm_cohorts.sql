-- ===============================================================================
-- Script: 06_rfm_cohorts.sql
-- Purpose: Build analytics.customer_rfm and analytics.cohort_retention.
--
-- RFM
--   Recency: days from last purchase to 2018-08-31.
--   R score: 5 = most recent, 1 = least recent. Bucket boundaries computed
--            with FLOOR(N * 0.2), FLOOR(N * 0.4), FLOOR(N * 0.6), FLOOR(N * 0.8)
--            on a rank ordered by (last_purchase_ts DESC, customer_unique_id ASC).
--            This exactly mirrors the pandas quintile rule.
--   Frequency: bands of 1, 2, 3+ orders within the analytic population.
--   Monetary: SUM(price). M score 1..5 by the same floor-of-fraction rule
--             on monetary ASC, customer_unique_id ASC.
--
-- Segments:
--   Champions: F >= 2 AND R >= 4
--   Loyal:     F >= 2 AND R =  3
--   At Risk:   F >= 2 AND R <= 2
--   New:       F =  1 AND R >= 4
--   Lost:      F =  1 AND R <= 3
--
-- Run order: after 05_facts.sql.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

IF OBJECT_ID('analytics.build_log', 'U') IS NULL
BEGIN
    RAISERROR('analytics.build_log missing — run 04_dimensions.sql first.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('tempdb..#analytics_run_ctx') IS NOT NULL DROP TABLE #analytics_run_ctx;
CREATE TABLE #analytics_run_ctx (run_id INT NOT NULL);
INSERT INTO #analytics_run_ctx (run_id)
SELECT ISNULL(MAX(run_id), 0) + 1 FROM analytics.build_log;

DECLARE @run_id INT = (SELECT run_id FROM #analytics_run_ctx);
PRINT 'RFM + cohorts layer run_id = ' + CAST(@run_id AS NVARCHAR(10));
GO

-- ===============================================================================
-- SECTION 1: customer_rfm
-- ===============================================================================

IF OBJECT_ID('analytics.customer_rfm', 'U') IS NOT NULL DROP TABLE analytics.customer_rfm;

CREATE TABLE analytics.customer_rfm (
    customer_key             INT            NOT NULL PRIMARY KEY,
    customer_unique_id       NVARCHAR(50)   NOT NULL,
    last_purchase_ts         DATETIME2      NOT NULL,
    recency_days             INT            NOT NULL,
    frequency                INT            NOT NULL,
    monetary                 DECIMAL(18,2)  NOT NULL,
    r_score                  INT            NOT NULL,
    f_band                   NVARCHAR(2)    NOT NULL,
    m_score                  INT            NOT NULL,
    segment                  NVARCHAR(20)   NOT NULL
);

;WITH customer_base AS (
    SELECT
        f.customer_key,
        f.customer_unique_id,
        MAX(f.order_purchase_timestamp) AS last_purchase_ts,
        COUNT(DISTINCT f.order_id)      AS frequency,
        SUM(oi.price)                   AS monetary
    FROM analytics.fact_orders f
    LEFT JOIN analytics.fact_order_items oi ON oi.order_key = f.order_key
    GROUP BY f.customer_key, f.customer_unique_id
),
total AS (
    SELECT COUNT(*) AS n FROM customer_base
),
r_ranked AS (
    SELECT
        cb.*,
        ROW_NUMBER() OVER (
            ORDER BY cb.last_purchase_ts DESC, cb.customer_unique_id ASC
        ) AS r_rank
    FROM customer_base cb
),
r_bucketed AS (
    SELECT
        rr.*,
        t.n,
        -- Boundaries as integers, matching pandas FLOOR(N * fraction)
        CAST(FLOOR(t.n * 0.2) AS INT) AS b20,
        CAST(FLOOR(t.n * 0.4) AS INT) AS b40,
        CAST(FLOOR(t.n * 0.6) AS INT) AS b60,
        CAST(FLOOR(t.n * 0.8) AS INT) AS b80
    FROM r_ranked rr
    CROSS JOIN total t
),
r_scored AS (
    SELECT
        rb.*,
        CASE
            WHEN rb.r_rank <= rb.b20 THEN 5
            WHEN rb.r_rank <= rb.b40 THEN 4
            WHEN rb.r_rank <= rb.b60 THEN 3
            WHEN rb.r_rank <= rb.b80 THEN 2
            ELSE 1
        END AS r_score
    FROM r_bucketed rb
),
m_ranked AS (
    SELECT
        rs.*,
        ROW_NUMBER() OVER (
            ORDER BY rs.monetary ASC, rs.customer_unique_id ASC
        ) AS m_rank
    FROM r_scored rs
),
m_scored AS (
    SELECT
        mr.*,
        CASE
            WHEN mr.m_rank <= mr.b20 THEN 1
            WHEN mr.m_rank <= mr.b40 THEN 2
            WHEN mr.m_rank <= mr.b60 THEN 3
            WHEN mr.m_rank <= mr.b80 THEN 4
            ELSE 5
        END AS m_score
    FROM m_ranked mr
)
INSERT INTO analytics.customer_rfm
    (customer_key, customer_unique_id, last_purchase_ts, recency_days,
     frequency, monetary, r_score, f_band, m_score, segment)
SELECT
    ms.customer_key,
    ms.customer_unique_id,
    ms.last_purchase_ts,
    DATEDIFF(DAY, ms.last_purchase_ts, '2018-08-31'),
    ms.frequency,
    ISNULL(ms.monetary, 0),
    ms.r_score,
    CASE
        WHEN ms.frequency = 1 THEN '1'
        WHEN ms.frequency = 2 THEN '2'
        ELSE '3+'
    END,
    ms.m_score,
    CASE
        WHEN ms.frequency >= 2 AND ms.r_score >= 4 THEN 'Champions'
        WHEN ms.frequency >= 2 AND ms.r_score =  3 THEN 'Loyal'
        WHEN ms.frequency >= 2 AND ms.r_score <= 2 THEN 'At Risk'
        WHEN ms.frequency =  1 AND ms.r_score >= 4 THEN 'New'
        ELSE 'Lost'
    END
FROM m_scored ms;

DECLARE @rfm_count INT = (SELECT COUNT(*) FROM analytics.customer_rfm);
EXEC analytics.usp_log_build
    @step_id          = 'CUSTOMER_RFM_BUILD',
    @step_description = 'One row per customer with R/F/M scores and segment',
    @object_name      = 'analytics.customer_rfm',
    @rows_written     = @rfm_count;
GO

PRINT 'analytics.customer_rfm built.';
GO

-- ===============================================================================
-- SECTION 2: cohort_retention
-- ===============================================================================

IF OBJECT_ID('analytics.cohort_retention', 'U') IS NOT NULL DROP TABLE analytics.cohort_retention;

CREATE TABLE analytics.cohort_retention (
    cohort_month      NVARCHAR(7)   NOT NULL,
    month_offset      INT           NOT NULL,
    cohort_size       INT           NOT NULL,
    active_customers  INT           NOT NULL,
    retention_pct     DECIMAL(7,4)  NOT NULL,
    PRIMARY KEY (cohort_month, month_offset)
);

;WITH orders_with_month AS (
    SELECT
        f.order_key,
        f.customer_key,
        f.customer_unique_id,
        f.order_purchase_timestamp,
        FORMAT(f.order_purchase_timestamp, 'yyyy-MM') AS order_month
    FROM analytics.fact_orders f
),
first_month AS (
    SELECT
        customer_key,
        MIN(order_purchase_timestamp) AS first_purchase_ts,
        FORMAT(MIN(order_purchase_timestamp), 'yyyy-MM') AS cohort_month
    FROM orders_with_month
    GROUP BY customer_key
),
orders_with_cohort AS (
    SELECT
        om.customer_key,
        fm.cohort_month,
        om.order_month,
        DATEDIFF(MONTH,
            DATEFROMPARTS(CAST(LEFT(fm.cohort_month,4) AS INT),
                          CAST(RIGHT(fm.cohort_month,2) AS INT), 1),
            DATEFROMPARTS(CAST(LEFT(om.order_month,4) AS INT),
                          CAST(RIGHT(om.order_month,2) AS INT), 1)
        ) AS month_offset
    FROM orders_with_month om
    JOIN first_month fm ON fm.customer_key = om.customer_key
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_key) AS size
    FROM first_month
    GROUP BY cohort_month
),
active AS (
    SELECT
        cohort_month,
        month_offset,
        COUNT(DISTINCT customer_key) AS active_customers
    FROM orders_with_cohort
    GROUP BY cohort_month, month_offset
)
INSERT INTO analytics.cohort_retention
    (cohort_month, month_offset, cohort_size, active_customers, retention_pct)
SELECT
    a.cohort_month,
    a.month_offset,
    cs.size,
    a.active_customers,
    CAST(100.0 * a.active_customers / cs.size AS DECIMAL(7,4))
FROM active a
JOIN cohort_size cs ON cs.cohort_month = a.cohort_month;

DECLARE @cohort_count INT = (SELECT COUNT(*) FROM analytics.cohort_retention);
EXEC analytics.usp_log_build
    @step_id          = 'COHORT_RETENTION_BUILD',
    @step_description = 'Cohort month x month_offset with cohort size and retention',
    @object_name      = 'analytics.cohort_retention',
    @rows_written     = @cohort_count;
GO

PRINT 'analytics.cohort_retention built.';
GO

-- ===============================================================================
-- SECTION 3: Verify
-- ===============================================================================

SELECT 'analytics.customer_rfm'      AS table_name, COUNT(*) AS rows FROM analytics.customer_rfm
UNION ALL SELECT 'analytics.cohort_retention', COUNT(*) FROM analytics.cohort_retention;
GO

SELECT r_score, COUNT(*) AS n FROM analytics.customer_rfm GROUP BY r_score ORDER BY r_score;
GO

SELECT m_score, COUNT(*) AS n FROM analytics.customer_rfm GROUP BY m_score ORDER BY m_score;
GO

SELECT segment, COUNT(*) AS n
FROM analytics.customer_rfm
GROUP BY segment
ORDER BY segment;
GO

SELECT f_band, COUNT(*) AS n
FROM analytics.customer_rfm
GROUP BY f_band
ORDER BY f_band;
GO

SELECT
    COUNT(*) AS total_customers,
    SUM(CASE WHEN f_band IN ('2','3+') THEN 1 ELSE 0 END) AS repeat_customers
FROM analytics.customer_rfm;
GO

SELECT step_id, object_name, rows_written
FROM analytics.build_log
WHERE run_id = (SELECT MAX(run_id) FROM analytics.build_log)
ORDER BY log_id;
GO