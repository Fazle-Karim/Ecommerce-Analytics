-- ===============================================================================
-- Script: 06_rfm_cohorts_tests.sql
-- Purpose: Validate analytics.customer_rfm and analytics.cohort_retention
--          against pinned expected values and internal consistency rules.
--          THROWs if any test fails.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#test_run_ctx') IS NOT NULL DROP TABLE #test_run_ctx;
CREATE TABLE #test_run_ctx (run_id INT NOT NULL);
INSERT INTO #test_run_ctx (run_id)
SELECT ISNULL(MAX(run_id), 0) + 1 FROM analytics.test_results;
GO

DECLARE @results TABLE (
    test_id     INT IDENTITY(1,1),
    test_name   NVARCHAR(100),
    expected    NVARCHAR(50),
    actual      NVARCHAR(50),
    status      NVARCHAR(10)
);

-- ===============================================================================
-- RFM row counts
-- ===============================================================================
INSERT INTO @results
SELECT 'rfm.row_count', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.customer_count';

INSERT INTO @results
SELECT 'rfm.distinct_keys', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(DISTINCT customer_key) AS n FROM analytics.customer_rfm) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.customer_count';

INSERT INTO @results
SELECT 'rfm.repeat_customers', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE f_band IN ('2','3+')) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.repeat_customers';

-- ===============================================================================
-- Segment counts
-- ===============================================================================
INSERT INTO @results
SELECT 'rfm.segment_champions', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE segment = 'Champions') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.segment_champions';

INSERT INTO @results
SELECT 'rfm.segment_loyal', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE segment = 'Loyal') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.segment_loyal';

INSERT INTO @results
SELECT 'rfm.segment_at_risk', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE segment = 'At Risk') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.segment_at_risk';

INSERT INTO @results
SELECT 'rfm.segment_recent_one_time', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE segment = 'Recent one-time') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.segment_recent_one_time';

INSERT INTO @results
SELECT 'rfm.segment_lapsed_one_time', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE segment = 'Lapsed one-time') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.segment_lapsed_one_time';

INSERT INTO @results
SELECT 'rfm.segment_unclassified', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE segment = 'UNCLASSIFIED') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.segment_unclassified';

INSERT INTO @results
SELECT 'rfm.segments_sum', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.customer_rfm
    WHERE segment IN ('Champions','Loyal','At Risk','Recent one-time','Lapsed one-time')
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.customer_count';

-- ===============================================================================
-- Frequency bands
-- ===============================================================================
INSERT INTO @results
SELECT 'rfm.f_band_1', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE f_band = '1') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.f_band_1';

INSERT INTO @results
SELECT 'rfm.f_band_2', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE f_band = '2') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.f_band_2';

INSERT INTO @results
SELECT 'rfm.f_band_3_plus', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm WHERE f_band = '3+') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.f_band_3_plus';

-- ===============================================================================
-- Semantic consistency
-- ===============================================================================
INSERT INTO @results
SELECT 'rfm.champions_semantics', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm
      WHERE segment = 'Champions' AND NOT (f_band IN ('2','3+') AND r_score >= 4)) t;

INSERT INTO @results
SELECT 'rfm.loyal_semantics', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm
      WHERE segment = 'Loyal' AND NOT (f_band IN ('2','3+') AND r_score = 3)) t;

INSERT INTO @results
SELECT 'rfm.at_risk_semantics', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm
      WHERE segment = 'At Risk' AND NOT (f_band IN ('2','3+') AND r_score <= 2)) t;

INSERT INTO @results
SELECT 'rfm.recent_one_time_semantics', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm
      WHERE segment = 'Recent one-time' AND NOT (f_band = '1' AND r_score >= 4)) t;

INSERT INTO @results
SELECT 'rfm.lapsed_one_time_semantics', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm
      WHERE segment = 'Lapsed one-time' AND NOT (f_band = '1' AND r_score <= 3)) t;

-- ===============================================================================
-- FK integrity
-- ===============================================================================
INSERT INTO @results
SELECT 'rfm.fk_customer_key', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.customer_rfm r
      WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_customer d WHERE d.customer_key = r.customer_key)) t;

INSERT INTO @results
SELECT 'rfm.every_dim_customer_has_rfm', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.dim_customer d
      WHERE NOT EXISTS (SELECT 1 FROM analytics.customer_rfm r WHERE r.customer_key = d.customer_key)) t;

-- ===============================================================================
-- Cohort checks
-- ===============================================================================
INSERT INTO @results
SELECT 'cohort.matrix_rows', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.cohort_retention WHERE cohort_month <> 'pre-2017') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'cohort.matrix_rows';

INSERT INTO @results
SELECT 'cohort.distinct_months', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(DISTINCT cohort_month) AS n FROM analytics.cohort_retention WHERE cohort_month <> 'pre-2017') t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'cohort.cohort_months';

INSERT INTO @results
SELECT 'cohort.pre_2017_row_present', '1', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 1 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.cohort_retention WHERE cohort_month = 'pre-2017') t;

INSERT INTO @results
SELECT 'cohort.pre_2017_size', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT cohort_size AS n FROM analytics.cohort_retention WHERE cohort_month = 'pre-2017'
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'cohort.pre_2017_customers';

INSERT INTO @results
SELECT 'cohort.offset_0_is_100pct', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.cohort_retention
      WHERE month_offset = 0 AND retention_pct <> 100) t;

INSERT INTO @results
SELECT 'cohort.active_le_size', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.cohort_retention
      WHERE active_customers > cohort_size) t;

INSERT INTO @results
SELECT 'cohort.matrix_plus_pre2017', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT SUM(cohort_size) AS n FROM (
        SELECT DISTINCT cohort_month, cohort_size FROM analytics.cohort_retention
    ) x
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'rfm.customer_count';

-- ===============================================================================
-- Show / persist / throw
-- ===============================================================================
SELECT test_name, expected, actual, status FROM @results ORDER BY test_id;

SELECT
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
    COUNT(*) AS total
FROM @results;

DECLARE @test_run_id INT = (SELECT run_id FROM #test_run_ctx);
INSERT INTO analytics.test_results (run_id, test_name, expected, actual, status)
SELECT @test_run_id, test_name, expected, actual, status FROM @results;

IF EXISTS (SELECT 1 FROM @results WHERE status = 'FAIL')
    THROW 51000, 'One or more RFM/cohort tests failed.', 1;

PRINT 'All RFM/cohort tests passed.';
GO