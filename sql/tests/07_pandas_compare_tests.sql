-- ===============================================================================
-- Script: 07_pandas_compare_tests.sql
-- Purpose: Prove SQL reproduces pandas cell-for-cell via EXCEPT both ways.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

SET NOCOUNT ON;

DECLARE @results TABLE (
    test_id     INT IDENTITY(1,1),
    test_name   NVARCHAR(100),
    expected    NVARCHAR(50),
    actual      NVARCHAR(50),
    status      NVARCHAR(10)
);

-- 1. RFM: SQL rows not in pandas
INSERT INTO @results
SELECT 'pandas_compare.rfm.sql_minus_pandas', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM (
        SELECT r.customer_unique_id, r.recency_days, r.frequency,
               CAST(r.monetary AS DECIMAL(18,2)) AS monetary,
               r.r_score, r.f_band, r.m_score, r.segment
        FROM analytics.customer_rfm r
        EXCEPT
        SELECT p.customer_unique_id, p.recency_days, p.frequency,
               p.monetary, p.r_score, p.f_band, p.m_score, p.segment
        FROM tests.pandas_rfm p
    ) x
) t;

-- 2. RFM: pandas rows not in SQL
INSERT INTO @results
SELECT 'pandas_compare.rfm.pandas_minus_sql', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM (
        SELECT p.customer_unique_id, p.recency_days, p.frequency,
               p.monetary, p.r_score, p.f_band, p.m_score, p.segment
        FROM tests.pandas_rfm p
        EXCEPT
        SELECT r.customer_unique_id, r.recency_days, r.frequency,
               CAST(r.monetary AS DECIMAL(18,2)) AS monetary,
               r.r_score, r.f_band, r.m_score, r.segment
        FROM analytics.customer_rfm r
    ) x
) t;

-- 3. Cohort: SQL rows not in pandas
INSERT INTO @results
SELECT 'pandas_compare.cohort.sql_minus_pandas', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM (
        SELECT cohort_month, month_offset, cohort_size, active_customers
        FROM analytics.cohort_retention
        EXCEPT
        SELECT cohort_month, month_offset, cohort_size, active_customers
        FROM tests.expected_cohort
    ) x
) t;

-- 4. Cohort: pandas rows not in SQL
INSERT INTO @results
SELECT 'pandas_compare.cohort.pandas_minus_sql', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM (
        SELECT cohort_month, month_offset, cohort_size, active_customers
        FROM tests.expected_cohort
        EXCEPT
        SELECT cohort_month, month_offset, cohort_size, active_customers
        FROM analytics.cohort_retention
    ) x
) t;

-- 5. Cohort cell count
INSERT INTO @results
SELECT 'pandas_compare.cohort.cell_count', '211', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = '211' THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM tests.expected_cohort) t;

-- 6. RFM row count parity
INSERT INTO @results
SELECT 'pandas_compare.rfm.row_count_parity', '0', CAST(t.delta AS NVARCHAR(50)),
       CASE WHEN t.delta = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT ABS(
        (SELECT COUNT(*) FROM tests.pandas_rfm)
      - (SELECT COUNT(*) FROM analytics.customer_rfm)
    ) AS delta
) t;

-- Show
SELECT test_name, expected, actual, status FROM @results ORDER BY test_id;

SELECT
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
    COUNT(*) AS total
FROM @results;

IF EXISTS (SELECT 1 FROM @results WHERE status = 'FAIL')
BEGIN
    PRINT '--- SQL-minus-pandas RFM samples (top 5) ---';
    SELECT TOP 5 * FROM (
        SELECT r.customer_unique_id, r.recency_days, r.frequency,
               CAST(r.monetary AS DECIMAL(18,2)) AS monetary,
               r.r_score, r.f_band, r.m_score, r.segment
        FROM analytics.customer_rfm r
        EXCEPT
        SELECT p.customer_unique_id, p.recency_days, p.frequency,
               p.monetary, p.r_score, p.f_band, p.m_score, p.segment
        FROM tests.pandas_rfm p
    ) x;

    PRINT '--- Cohort samples (top 5) ---';
    SELECT TOP 5 * FROM (
        SELECT cohort_month, month_offset, cohort_size, active_customers
        FROM analytics.cohort_retention
        EXCEPT
        SELECT cohort_month, month_offset, cohort_size, active_customers
        FROM tests.expected_cohort
    ) x;

    THROW 51000, 'One or more pandas-comparison tests failed.', 1;
END;

PRINT 'All pandas-comparison tests passed.';
GO