-- ===============================================================================
-- Script: 06_rfm_cohorts.sql
-- Purpose: Build analytics.customer_rfm and analytics.cohort_retention.
--
-- RFM
--   Recency: elapsed whole days between last purchase and 2018-08-31.
--            Uses DATEDIFF(SECOND, ...) / 86400 with FLOOR, so SQL matches
--            pandas (.dt.days floors elapsed time).
--   R score: 5 = most recent, 1 = least recent. FLOOR(N * 0.2) bucket rule
--            on a rank ordered by (last_purchase_ts DESC, customer_unique_id ASC).
--   Frequency: bands 1, 2, 3+.
--   Monetary: SUM(price). M score by FLOOR(N * 0.2) on
--            (monetary ASC, customer_unique_id ASC).
--
-- Segments:
--   Champions / Loyal / At Risk for F >= 2
--   Recent one-time / Lapsed one-time for F = 1
--   UNCLASSIFIED guard.
--
-- Cohorts
--   Cohort month = month of the customer's FIRST-EVER in-scope order across
--                  all dates (from clean.orders).
--   Pre-2017 customers -> single sentinel row.
--   Full triangle: every observable (cohort_month, month_offset) cell,
--                  zero-filled, built with GENERATE_SERIES.
--
-- Run order: after 05_facts.sql and 04_dimensions.sql.
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

-- Constants (declared once, reused)
DECLARE @SNAPSHOT_DATE      DATE = '2018-08-31';
DECLARE @SNAPSHOT_MONTH     DATE = '2018-08-01';
DECLARE @WINDOW_START       DATE = '2017-01-01';
DECLARE @WINDOW_END         DATE = '2018-09-01';
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
    FLOOR(DATEDIFF(SECOND, ms.last_purchase_ts, '2018-08-31 00:00:00') / 86400.0),
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
        WHEN ms.frequency =  1 AND ms.r_score >= 4 THEN 'Recent one-time'
        WHEN ms.frequency =  1 AND ms.r_score <= 3 THEN 'Lapsed one-time'
        ELSE 'UNCLASSIFIED'
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
    cohort_month       NVARCHAR(10)   NOT NULL,
    cohort_month_start DATE           NULL,
    month_offset       INT            NOT NULL,
    cohort_size        INT            NOT NULL,
    active_customers   INT            NOT NULL,
    retention_pct      DECIMAL(7,4)   NOT NULL,
    PRIMARY KEY (cohort_month, month_offset)
);

-- 2a. Full-history first purchase per customer
IF OBJECT_ID('tempdb..#cust_first') IS NOT NULL DROP TABLE #cust_first;
CREATE TABLE #cust_first (
    customer_unique_id NVARCHAR(50) NOT NULL PRIMARY KEY,
    first_purchase_ts  DATETIME2    NOT NULL,
    first_cohort_month NVARCHAR(10) NOT NULL
);

INSERT INTO #cust_first (customer_unique_id, first_purchase_ts, first_cohort_month)
SELECT
    c.customer_unique_id,
    MIN(o.order_purchase_timestamp) AS first_purchase_ts,
    CASE
        WHEN MIN(o.order_purchase_timestamp) < '2017-01-01' THEN 'pre-2017'
        ELSE CONVERT(CHAR(7), MIN(o.order_purchase_timestamp), 120)
    END
FROM clean.orders o
JOIN clean.customers c ON c.customer_id = o.customer_id
WHERE o.order_status IN ('delivered','shipped','invoiced','processing','approved')
GROUP BY c.customer_unique_id;
GO

-- 2b. Pre-2017 sentinel (only customers who appear in RFM)
INSERT INTO analytics.cohort_retention
    (cohort_month, cohort_month_start, month_offset,
     cohort_size, active_customers, retention_pct)
SELECT
    'pre-2017',
    NULL,
    0,
    COUNT(*),
    COUNT(*),
    CAST(100.0 AS DECIMAL(7,4))
FROM analytics.customer_rfm r
JOIN #cust_first cf ON cf.customer_unique_id = r.customer_unique_id
WHERE cf.first_cohort_month = 'pre-2017';
GO

-- 2c. Every in-window order of in-window-first customers
IF OBJECT_ID('tempdb..#cohort_orders') IS NOT NULL DROP TABLE #cohort_orders;
CREATE TABLE #cohort_orders (
    customer_unique_id NVARCHAR(50) NOT NULL,
    cohort_month       NVARCHAR(7)  NOT NULL,
    order_month        NVARCHAR(7)  NOT NULL,
    month_offset       INT           NOT NULL
);

INSERT INTO #cohort_orders (customer_unique_id, cohort_month, order_month, month_offset)
SELECT
    c.customer_unique_id,
    cf.first_cohort_month,
    CONVERT(CHAR(7), o.order_purchase_timestamp, 120),
    DATEDIFF(MONTH,
        DATEFROMPARTS(CAST(LEFT(cf.first_cohort_month, 4) AS INT),
                      CAST(RIGHT(cf.first_cohort_month, 2) AS INT), 1),
        DATEFROMPARTS(CAST(LEFT(CONVERT(CHAR(7), o.order_purchase_timestamp, 120), 4) AS INT),
                      CAST(RIGHT(CONVERT(CHAR(7), o.order_purchase_timestamp, 120), 2) AS INT), 1)
    ) AS month_offset
FROM clean.orders o
JOIN clean.customers c ON c.customer_id = o.customer_id
JOIN #cust_first cf ON cf.customer_unique_id = c.customer_unique_id
WHERE o.order_status IN ('delivered','shipped','invoiced','processing','approved')
  AND cf.first_cohort_month <> 'pre-2017';
GO

-- 2d. Cohort sizes
IF OBJECT_ID('tempdb..#cohort_size') IS NOT NULL DROP TABLE #cohort_size;
CREATE TABLE #cohort_size (
    cohort_month NVARCHAR(7) NOT NULL PRIMARY KEY,
    cohort_size  INT          NOT NULL
);

INSERT INTO #cohort_size (cohort_month, cohort_size)
SELECT first_cohort_month, COUNT(*)
FROM #cust_first
WHERE first_cohort_month <> 'pre-2017'
GROUP BY first_cohort_month;
GO

-- 2e. Active counts per (cohort_month, month_offset)
IF OBJECT_ID('tempdb..#active') IS NOT NULL DROP TABLE #active;
CREATE TABLE #active (
    cohort_month     NVARCHAR(7) NOT NULL,
    month_offset     INT         NOT NULL,
    active_customers INT         NOT NULL,
    PRIMARY KEY (cohort_month, month_offset)
);

INSERT INTO #active (cohort_month, month_offset, active_customers)
SELECT cohort_month, month_offset, COUNT(DISTINCT customer_unique_id)
FROM #cohort_orders
GROUP BY cohort_month, month_offset;
GO

-- 2f. Full triangle: every observable (cohort_month, month_offset)
INSERT INTO analytics.cohort_retention
    (cohort_month, cohort_month_start, month_offset,
     cohort_size, active_customers, retention_pct)
SELECT
    cs.cohort_month,
    DATEFROMPARTS(CAST(LEFT(cs.cohort_month, 4) AS INT),
                  CAST(RIGHT(cs.cohort_month, 2) AS INT), 1) AS cohort_month_start,
    s.value AS month_offset,
    cs.cohort_size,
    ISNULL(a.active_customers, 0),
    CAST(100.0 * ISNULL(a.active_customers, 0) / cs.cohort_size AS DECIMAL(7,4))
FROM #cohort_size cs
CROSS APPLY GENERATE_SERIES(
    0,
    DATEDIFF(MONTH,
        DATEFROMPARTS(CAST(LEFT(cs.cohort_month, 4) AS INT),
                      CAST(RIGHT(cs.cohort_month, 2) AS INT), 1),
        '2018-08-01'
    )
) AS s
LEFT JOIN #active a
    ON a.cohort_month = cs.cohort_month
   AND a.month_offset = s.value;
GO

DECLARE @cohort_count INT = (SELECT COUNT(*) FROM analytics.cohort_retention);
EXEC analytics.usp_log_build
    @step_id          = 'COHORT_RETENTION_BUILD',
    @step_description = 'Full triangle with zero-fill and pre-2017 sentinel',
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

SELECT segment, COUNT(*) AS n
FROM analytics.customer_rfm
GROUP BY segment
ORDER BY segment;
GO

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN cohort_month = 'pre-2017' THEN 1 ELSE 0 END) AS pre_2017_rows,
    SUM(CASE WHEN cohort_month <> 'pre-2017' THEN 1 ELSE 0 END) AS matrix_rows,
    COUNT(DISTINCT CASE WHEN cohort_month <> 'pre-2017' THEN cohort_month END) AS distinct_cohorts
FROM analytics.cohort_retention;
GO

SELECT
    (SELECT SUM(cohort_size) FROM (
        SELECT DISTINCT cohort_month, cohort_size FROM analytics.cohort_retention
    ) x) AS total_customers_in_matrix_and_pre2017;
GO

SELECT TOP 5 cohort_month, month_offset, cohort_size, active_customers, retention_pct
FROM analytics.cohort_retention
WHERE cohort_month <> 'pre-2017'
ORDER BY cohort_month, month_offset;
GO

SELECT step_id, object_name, rows_written
FROM analytics.build_log
WHERE run_id = (SELECT MAX(run_id) FROM analytics.build_log)
ORDER BY log_id;
GO