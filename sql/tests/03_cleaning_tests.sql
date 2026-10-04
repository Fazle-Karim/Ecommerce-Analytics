-- ===============================================================================
-- Script: 03_cleaning_tests.sql
-- Purpose: Validate the clean layer against expected control totals.
--          Every test returns one row: test_name | expected | actual | status.
-- Run after 03_cleaning.sql.
-- ===============================================================================

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

-- -------------------------------------------------------------------------------
-- 1. Row counts per clean table
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.customers', '99441', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 99441 THEN 'PASS' ELSE 'FAIL' END
FROM clean.customers;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.sellers', '3095', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 3095 THEN 'PASS' ELSE 'FAIL' END
FROM clean.sellers;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.geolocation', '19011', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 19011 THEN 'PASS' ELSE 'FAIL' END
FROM clean.geolocation;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.orders', '99441', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 99441 THEN 'PASS' ELSE 'FAIL' END
FROM clean.orders;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.order_items', '112650', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 112650 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.payments', '103886', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 103886 THEN 'PASS' ELSE 'FAIL' END
FROM clean.payments;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.category_translation', '74', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 74 THEN 'PASS' ELSE 'FAIL' END
FROM clean.category_translation;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.products', '32951', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 32951 THEN 'PASS' ELSE 'FAIL' END
FROM clean.products;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'row_count.reviews', '98673', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 98673 THEN 'PASS' ELSE 'FAIL' END
FROM clean.reviews;

-- -------------------------------------------------------------------------------
-- 2. Sums: clean == raw
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'sum.price.raw_equals_clean',
    CAST((SELECT SUM(TRY_CAST(price AS DECIMAL(18,2))) FROM raw.order_items) AS NVARCHAR(50)),
    CAST((SELECT SUM(price) FROM clean.order_items) AS NVARCHAR(50)),
    CASE
        WHEN (SELECT SUM(TRY_CAST(price AS DECIMAL(18,2))) FROM raw.order_items)
           = (SELECT SUM(price) FROM clean.order_items)
        THEN 'PASS' ELSE 'FAIL'
    END;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'sum.freight.raw_equals_clean',
    CAST((SELECT SUM(TRY_CAST(freight_value AS DECIMAL(18,2))) FROM raw.order_items) AS NVARCHAR(50)),
    CAST((SELECT SUM(freight_value) FROM clean.order_items) AS NVARCHAR(50)),
    CASE
        WHEN (SELECT SUM(TRY_CAST(freight_value AS DECIMAL(18,2))) FROM raw.order_items)
           = (SELECT SUM(freight_value) FROM clean.order_items)
        THEN 'PASS' ELSE 'FAIL'
    END;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'sum.payment.raw_equals_clean',
    CAST((SELECT SUM(TRY_CAST(payment_value AS DECIMAL(18,2))) FROM raw.payments) AS NVARCHAR(50)),
    CAST((SELECT SUM(payment_value) FROM clean.payments) AS NVARCHAR(50)),
    CASE
        WHEN (SELECT SUM(TRY_CAST(payment_value AS DECIMAL(18,2))) FROM raw.payments)
           = (SELECT SUM(payment_value) FROM clean.payments)
        THEN 'PASS' ELSE 'FAIL'
    END;

-- -------------------------------------------------------------------------------
-- 3. Zero unparseable values: no NULLs introduced by TRY_CONVERT where raw had values
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'unparseable.order_purchase_timestamp', '0',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean.orders
WHERE order_purchase_timestamp IS NULL
  AND order_id IN (SELECT order_id FROM raw.orders WHERE order_purchase_timestamp IS NOT NULL);

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'unparseable.price', '0',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items
WHERE price IS NULL
  AND order_id IN (SELECT order_id FROM raw.order_items WHERE price IS NOT NULL);

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'unparseable.review_score', '0',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean.reviews
WHERE review_score IS NULL;

-- -------------------------------------------------------------------------------
-- 4. Funnel: 99,441 -> 98,202 -> 97,905 from clean.orders using half-open interval
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'funnel.raw_total', '99441',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 99441 THEN 'PASS' ELSE 'FAIL' END
FROM clean.orders;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'funnel.in_scope_status', '98202',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 98202 THEN 'PASS' ELSE 'FAIL' END
FROM clean.orders
WHERE order_status IN ('delivered','shipped','invoiced','processing','approved');

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'funnel.in_scope_and_in_window', '97905',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 97905 THEN 'PASS' ELSE 'FAIL' END
FROM clean.orders
WHERE order_status IN ('delivered','shipped','invoiced','processing','approved')
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';

-- -------------------------------------------------------------------------------
-- 5. GMV and freight for analytic population
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'gmv.analytic_population', '13449529.68',
    CAST(SUM(oi.price) AS NVARCHAR(50)),
    CASE WHEN SUM(oi.price) = 13449529.68 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items oi
WHERE oi.order_id IN (
    SELECT order_id FROM clean.orders
    WHERE order_status IN ('delivered','shipped','invoiced','processing','approved')
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
);

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'freight.analytic_population', '2234177.06',
    CAST(SUM(oi.freight_value) AS NVARCHAR(50)),
    CASE WHEN SUM(oi.freight_value) = 2234177.06 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items oi
WHERE oi.order_id IN (
    SELECT order_id FROM clean.orders
    WHERE order_status IN ('delivered','shipped','invoiced','processing','approved')
      AND order_purchase_timestamp >= '2017-01-01'
      AND order_purchase_timestamp <  '2018-09-01'
);

-- -------------------------------------------------------------------------------
-- 6. Flag counts
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'flags.shipping_limit_anomalies', '4',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items
WHERE flag_shipping_limit_anomaly = 1;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'flags.payments_undefined_type', '3',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 3 THEN 'PASS' ELSE 'FAIL' END
FROM clean.payments
WHERE flag_undefined_type = 1;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'flags.products_missing_dimensions', '2',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 2 THEN 'PASS' ELSE 'FAIL' END
FROM clean.products
WHERE flag_missing_dimensions = 1;

-- -------------------------------------------------------------------------------
-- 7. Zip prefix length check (all should be 5)
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'zip.customers_len5', '99441',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 99441 THEN 'PASS' ELSE 'FAIL' END
FROM clean.customers
WHERE LEN(customer_zip_code_prefix) = 5;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'zip.sellers_len5', '3095',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 3095 THEN 'PASS' ELSE 'FAIL' END
FROM clean.sellers
WHERE LEN(seller_zip_code_prefix) = 5;

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'zip.geolocation_len5', '19011',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 19011 THEN 'PASS' ELSE 'FAIL' END
FROM clean.geolocation
WHERE LEN(geolocation_zip_code_prefix) = 5;

-- -------------------------------------------------------------------------------
-- 8. Foreign key: order_items.order_id in orders
-- -------------------------------------------------------------------------------
INSERT INTO @results (test_name, expected, actual, status)
SELECT 'fk.order_items.order_id_in_orders', '0',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM clean.orders o WHERE o.order_id = oi.order_id);

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'fk.orders.customer_id_in_customers', '0',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean.orders o
WHERE NOT EXISTS (SELECT 1 FROM clean.customers c WHERE c.customer_id = o.customer_id);

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'fk.order_items.product_id_in_products', '0',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM clean.products p WHERE p.product_id = oi.product_id);

INSERT INTO @results (test_name, expected, actual, status)
SELECT 'fk.order_items.seller_id_in_sellers', '0',
    CAST(COUNT(*) AS NVARCHAR(50)),
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM clean.order_items oi
WHERE NOT EXISTS (SELECT 1 FROM clean.sellers s WHERE s.seller_id = oi.seller_id);

-- -------------------------------------------------------------------------------
-- Report
-- -------------------------------------------------------------------------------
SELECT test_name, expected, actual, status
FROM @results
ORDER BY test_id;

SELECT
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
    COUNT(*) AS total
FROM @results;
GO