-- ===============================================================================
-- Script: 03_cleaning_tests.sql
-- Purpose: Validate the clean layer against pinned expected values.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

SET NOCOUNT ON;

IF OBJECT_ID('clean.test_results', 'U') IS NULL
BEGIN
    CREATE TABLE clean.test_results (
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
SELECT ISNULL(MAX(run_id), 0) + 1 FROM clean.test_results;
GO

DECLARE @results TABLE (
    test_id     INT IDENTITY(1,1),
    test_name   NVARCHAR(100),
    expected    NVARCHAR(50),
    actual      NVARCHAR(50),
    status      NVARCHAR(10)
);

-- ===============================================================================
-- Row counts
-- ===============================================================================
INSERT INTO @results
SELECT 'row_count.customers', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.customers) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.customers';

INSERT INTO @results
SELECT 'row_count.sellers', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.sellers) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.sellers';

INSERT INTO @results
SELECT 'row_count.geolocation', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.geolocation) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.geolocation';

INSERT INTO @results
SELECT 'row_count.orders', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.orders) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.orders';

INSERT INTO @results
SELECT 'row_count.order_items', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.order_items) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.order_items';

INSERT INTO @results
SELECT 'row_count.payments', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.payments) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.payments';

INSERT INTO @results
SELECT 'row_count.category_translation', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.category_translation) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.category_translation';

INSERT INTO @results
SELECT 'row_count.products', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.products) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.products';

INSERT INTO @results
SELECT 'row_count.reviews', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.reviews) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'row_count.reviews';

-- ===============================================================================
-- Sums (clean vs pinned JSON)
-- ===============================================================================
INSERT INTO @results
SELECT 'sum.price.clean_equals_pinned', e.expected_value,
       CAST(CAST(t.s AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.s AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(price) AS s FROM clean.order_items) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'sum.price.clean_equals_pinned';

INSERT INTO @results
SELECT 'sum.freight.clean_equals_pinned', e.expected_value,
       CAST(CAST(t.s AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.s AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(freight_value) AS s FROM clean.order_items) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'sum.freight.clean_equals_pinned';

INSERT INTO @results
SELECT 'sum.payment.clean_equals_pinned', e.expected_value,
       CAST(CAST(t.s AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.s AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(payment_value) AS s FROM clean.payments) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'sum.payment.clean_equals_pinned';

-- ===============================================================================
-- Unparseable-value checks
-- ===============================================================================
INSERT INTO @results
SELECT 'unparseable.order_purchase_timestamp', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.orders
    WHERE order_purchase_timestamp IS NULL
      AND order_id IN (SELECT order_id FROM raw.orders WHERE order_purchase_timestamp IS NOT NULL)
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'unparseable.order_purchase_timestamp';

INSERT INTO @results
SELECT 'unparseable.price', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.order_items
    WHERE price IS NULL
      AND order_id IN (SELECT order_id FROM raw.order_items WHERE price IS NOT NULL)
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'unparseable.price';

INSERT INTO @results
SELECT 'unparseable.review_score', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.reviews WHERE review_score IS NULL) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'unparseable.review_score';

-- ===============================================================================
-- Funnel
-- ===============================================================================
INSERT INTO @results
SELECT 'funnel.raw_total', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.orders) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'funnel.raw_total';

INSERT INTO @results
SELECT 'funnel.in_scope_status', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.orders
    WHERE order_status IN ('delivered','shipped','invoiced','processing','approved')
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'funnel.in_scope_status';

INSERT INTO @results
SELECT 'funnel.in_scope_and_in_window', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.orders
    WHERE order_status IN ('delivered','shipped','invoiced','processing','approved')
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'funnel.in_scope_and_in_window';

-- ===============================================================================
-- GMV, freight
-- ===============================================================================
INSERT INTO @results
SELECT 'gmv.analytic_population', e.expected_value,
       CAST(CAST(t.s AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.s AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT SUM(oi.price) AS s FROM clean.order_items oi
    WHERE oi.order_id IN (
        SELECT order_id FROM clean.orders
        WHERE order_status IN ('delivered','shipped','invoiced','processing','approved')
          AND order_purchase_timestamp >= '2017-01-01'
          AND order_purchase_timestamp <  '2018-09-01'
    )
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'gmv.analytic_population';

INSERT INTO @results
SELECT 'freight.analytic_population', e.expected_value,
       CAST(CAST(t.s AS DECIMAL(18,2)) AS NVARCHAR(50)),
       CASE WHEN CAST(t.s AS DECIMAL(18,2)) = CAST(e.expected_value AS DECIMAL(18,2))
            THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT SUM(oi.freight_value) AS s FROM clean.order_items oi
    WHERE oi.order_id IN (
        SELECT order_id FROM clean.orders
        WHERE order_status IN ('delivered','shipped','invoiced','processing','approved')
          AND order_purchase_timestamp >= '2017-01-01'
          AND order_purchase_timestamp <  '2018-09-01'
    )
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'freight.analytic_population';

-- ===============================================================================
-- Flags
-- ===============================================================================
INSERT INTO @results
SELECT 'flags.shipping_limit_anomalies', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.order_items WHERE flag_shipping_limit_anomaly = 1) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'flags.shipping_limit_anomalies';

INSERT INTO @results
SELECT 'flags.payments_undefined_type', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.payments WHERE flag_undefined_type = 1) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'flags.payments_undefined_type';

INSERT INTO @results
SELECT 'flags.products_missing_dimensions', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.products WHERE flag_missing_dimensions = 1) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'flags.products_missing_dimensions';

-- ===============================================================================
-- Zip length checks
-- ===============================================================================
INSERT INTO @results
SELECT 'zip.customers_len5', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.customers WHERE LEN(customer_zip_code_prefix) = 5) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'zip.customers_len5';

INSERT INTO @results
SELECT 'zip.sellers_len5', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.sellers WHERE LEN(seller_zip_code_prefix) = 5) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'zip.sellers_len5';

INSERT INTO @results
SELECT 'zip.geolocation_len5', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.geolocation WHERE LEN(geolocation_zip_code_prefix) = 5) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'zip.geolocation_len5';

-- ===============================================================================
-- FK integrity
-- ===============================================================================
INSERT INTO @results
SELECT 'fk.order_items.order_id_in_orders', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.order_items oi
    WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = oi.order_id)
) t;

INSERT INTO @results
SELECT 'fk.orders.customer_id_in_customers', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.orders o
    WHERE NOT EXISTS (SELECT 1 FROM clean.customers c WHERE c.customer_id = o.customer_id)
) t;

INSERT INTO @results
SELECT 'fk.order_items.product_id_in_products', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.order_items oi
    WHERE NOT EXISTS (SELECT 1 FROM clean.products p WHERE p.product_id = oi.product_id)
) t;

INSERT INTO @results
SELECT 'fk.order_items.seller_id_in_sellers', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.order_items oi
    WHERE NOT EXISTS (SELECT 1 FROM clean.sellers s WHERE s.seller_id = oi.seller_id)
) t;

INSERT INTO @results
SELECT 'fk.payments.order_id_in_orders', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.payments p
    WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = p.order_id)
) t;

INSERT INTO @results
SELECT 'fk.reviews.order_id_in_orders', '0', CAST(t.n AS NVARCHAR(50)),
       CASE WHEN t.n = 0 THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n FROM clean.reviews r
    WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = r.order_id)
) t;

-- ===============================================================================
-- Geolocation identity
-- ===============================================================================
INSERT INTO @results
SELECT 'geolocation.identity_raw_equals_clean_and_filtered', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT SUM(sample_count + filtered_count) AS n FROM clean.geolocation) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'geolocation.identity_raw_equals_clean_and_filtered';

INSERT INTO @results
SELECT 'geolocation.prefixes_missing_coords', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (SELECT COUNT(*) AS n FROM clean.geolocation WHERE is_coordinates_missing = 1) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'geolocation.prefixes_missing_coords';

-- ===============================================================================
-- Category integrity
-- ===============================================================================
INSERT INTO @results
SELECT 'category.no_unknown_from_nonnull_raw', e.expected_value, CAST(t.n AS NVARCHAR(50)),
       CASE WHEN CAST(t.n AS NVARCHAR(50)) = e.expected_value THEN 'PASS' ELSE 'FAIL' END
FROM (
    SELECT COUNT(*) AS n
    FROM clean.products p
    INNER JOIN raw.products r ON r.product_id = p.product_id
    WHERE r.product_category_name IS NOT NULL
      AND p.product_category_name = 'unknown'
) t
CROSS JOIN clean.test_expected_values e WHERE e.test_name = 'category.no_unknown_from_nonnull_raw';

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
INSERT INTO clean.test_results (run_id, test_name, expected, actual, status)
SELECT @test_run_id, test_name, expected, actual, status FROM @results;

IF EXISTS (SELECT 1 FROM @results WHERE status = 'FAIL')
    THROW 51000, 'One or more cleaning tests failed.', 1;

PRINT 'All cleaning tests passed.';
GO