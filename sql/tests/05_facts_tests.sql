-- ===============================================================================
-- Script: 05_facts_tests.sql
-- Purpose: Validate the analytics layer against pinned expected values.
--          Expected values come from clean.test_expected_values.
--          Results persisted to analytics.test_results.
--          THROWs if any test fails.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID('analytics.test_results', 'U') IS NULL
BEGIN
    CREATE TABLE analytics.test_results (
        result_id   INT IDENTITY(1,1) PRIMARY KEY,
        run_id      INT            NOT NULL,
        test_name   NVARCHAR(100)  NOT NULL,
        expected    NVARCHAR(50)   NOT NULL,
        actual      NVARCHAR(50)   NOT NULL,
        status      NVARCHAR(10)   NOT NULL,
        tested_at   DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
GO

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

-- -------------------------------------------------------------------------------
-- Row counts
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'fact_orders.row_count', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.fact_orders) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.fact_orders';

INSERT INTO @results
SELECT 'excluded_orders.row_count', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.excluded_orders) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.excluded_orders';

INSERT INTO @results
SELECT 'fact_plus_excluded', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT (SELECT COUNT(*) FROM analytics.fact_orders)
         + (SELECT COUNT(*) FROM analytics.excluded_orders) AS n
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.fact_plus_excluded';

INSERT INTO @results
SELECT 'dim_date.row_count', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.dim_date) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.dim_date';

INSERT INTO @results
SELECT 'dim_customer.row_count', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.dim_customer) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.dim_customer';

INSERT INTO @results
SELECT 'dim_product.row_count', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.dim_product) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.dim_product';

INSERT INTO @results
SELECT 'dim_seller.row_count', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM analytics.dim_seller) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.dim_seller';

-- -------------------------------------------------------------------------------
-- GMV and freight on fact_order_items
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'gmv.fact_order_items', e.expected_value,
       CAST(CAST(t.s AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.s AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(price) AS s FROM analytics.fact_order_items) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'gmv.analytic_population';

INSERT INTO @results
SELECT 'freight.fact_order_items', e.expected_value,
       CAST(CAST(t.s AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.s AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(freight_value) AS s FROM analytics.fact_order_items) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'freight.analytic_population';

-- -------------------------------------------------------------------------------
-- Late rate
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'late.orders', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(CAST(is_late AS INT)) AS n FROM analytics.fact_orders) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.late_orders';

INSERT INTO @results
SELECT 'late.denominator', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_orders
    WHERE order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.late_denominator';

INSERT INTO @results
SELECT 'late.rate_pct', e.expected_value, CAST(t.rate AS NVARCHAR(50)),
       CASE WHEN CAST(t.rate AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT CAST(
        100.0 * SUM(CAST(is_late AS INT))
        / NULLIF(SUM(CASE WHEN order_status = 'delivered'
                          AND order_delivered_customer_date IS NOT NULL
                         THEN 1 ELSE 0 END), 0)
    AS DECIMAL(5,2)) AS rate
    FROM analytics.fact_orders
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.late_rate_pct';

-- -------------------------------------------------------------------------------
-- Review means
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'review.avg_all_orders', e.expected_value,
       CAST(CAST(t.m AS DECIMAL(10,4)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.m AS DECIMAL(10,4)) = CAST(e.expected_value AS DECIMAL(10,4))
            THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT AVG(CAST(r.review_score AS DECIMAL(10,4))) AS m
    FROM clean.reviews r
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.avg_review_score';

INSERT INTO @results
SELECT 'review.avg_late', e.expected_value,
       CAST(CAST(t.m AS DECIMAL(10,4)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.m AS DECIMAL(10,4)) = CAST(e.expected_value AS DECIMAL(10,4))
            THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT AVG(CAST(review_score AS DECIMAL(10,4))) AS m
    FROM analytics.fact_orders
    WHERE is_late = 1 AND review_score IS NOT NULL
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.avg_review_late';

INSERT INTO @results
SELECT 'review.avg_on_time', e.expected_value,
       CAST(CAST(t.m AS DECIMAL(10,4)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.m AS DECIMAL(10,4)) = CAST(e.expected_value AS DECIMAL(10,4))
            THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT AVG(CAST(review_score AS DECIMAL(10,4))) AS m
    FROM analytics.fact_orders
    WHERE is_late = 0
      AND review_score IS NOT NULL
      AND order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.avg_review_on_time';

-- -------------------------------------------------------------------------------
-- Payment residual
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'payment.residual', e.expected_value,
       CAST(CAST(t.residual AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.residual AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT
        (SELECT SUM(payment_total) FROM analytics.fact_orders)
      - (SELECT SUM(price) + SUM(freight_value) FROM analytics.fact_order_items) AS residual
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'analytic.payment_residual';

-- -------------------------------------------------------------------------------
-- Monthly series: spot-check 3 months
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'monthly.2017_01.in_scope', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_orders
    WHERE date_key >= 20170101 AND date_key < 20170201
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'monthly.2017_01.in_scope';

INSERT INTO @results
SELECT 'monthly.2018_08.in_scope', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_orders
    WHERE date_key >= 20180801 AND date_key < 20180901
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'monthly.2018_08.in_scope';

INSERT INTO @results
SELECT 'monthly.2017_11.in_scope', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_orders
    WHERE date_key >= 20171101 AND date_key < 20171201
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'monthly.2017_11.in_scope';

-- -------------------------------------------------------------------------------
-- FK integrity on fact tables
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'fk.fact_orders.customer_key', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_orders f
    WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_customer d WHERE d.customer_key = f.customer_key)
) t;

INSERT INTO @results
SELECT 'fk.fact_orders.date_key', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_orders f
    WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_date d WHERE d.date_key = f.date_key)
) t;

INSERT INTO @results
SELECT 'fk.fact_order_items.order_key', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_order_items f
    WHERE NOT EXISTS (SELECT 1 FROM analytics.fact_orders fo WHERE fo.order_key = f.order_key)
) t;

INSERT INTO @results
SELECT 'fk.fact_order_items.product_key', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_order_items f
    WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_product d WHERE d.product_key = f.product_key)
) t;

INSERT INTO @results
SELECT 'fk.fact_order_items.seller_key', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM analytics.fact_order_items f
    WHERE NOT EXISTS (SELECT 1 FROM analytics.dim_seller d WHERE d.seller_key = f.seller_key)
) t;

-- -------------------------------------------------------------------------------
-- Item grain check: one row per (order_id, order_item_id)
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'fact_order_items.no_duplicates', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM (
        SELECT order_id, order_item_id
        FROM analytics.fact_order_items
        GROUP BY order_id, order_item_id
        HAVING COUNT(*) > 1
    ) x
) t;

-- -------------------------------------------------------------------------------
-- Show + persist + throw on failure
-- -------------------------------------------------------------------------------
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
    THROW 51000, 'One or more analytics tests failed.', 1;

PRINT 'All analytics tests passed.';
GO