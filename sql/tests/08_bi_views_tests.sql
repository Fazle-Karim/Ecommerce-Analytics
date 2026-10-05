-- ===============================================================================
-- Script: 08_bi_views_tests.sql
-- Purpose: Validate every bi view exists, has the right shape, and is
--          slim (no timestamps, no natural-key text columns except order_status).
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

-- -------------------------------------------------------------------------------
-- View existence
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'bi.view.dim_date',           '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'dim_date';

INSERT INTO @results
SELECT 'bi.view.dim_customer',       '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'dim_customer';

INSERT INTO @results
SELECT 'bi.view.dim_product',        '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'dim_product';

INSERT INTO @results
SELECT 'bi.view.dim_seller',         '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'dim_seller';

INSERT INTO @results
SELECT 'bi.view.dim_order',          '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'dim_order';

INSERT INTO @results
SELECT 'bi.view.fact_orders',        '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'fact_orders';

INSERT INTO @results
SELECT 'bi.view.fact_order_items',   '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'fact_order_items';

INSERT INTO @results
SELECT 'bi.view.customer_rfm',       '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'customer_rfm';

INSERT INTO @results
SELECT 'bi.view.cohort_retention',   '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'cohort_retention';

INSERT INTO @results
SELECT 'bi.view.cohort_pre2017',     '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE s.name = 'bi' AND v.name = 'cohort_pre2017';

-- -------------------------------------------------------------------------------
-- Row count parity with source tables
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'bi.dim_customer_row_count', '94703', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 94703 THEN 'PASS' ELSE 'FAIL' END
FROM bi.dim_customer;

INSERT INTO @results
SELECT 'bi.fact_orders_row_count', '97905', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 97905 THEN 'PASS' ELSE 'FAIL' END
FROM bi.fact_orders;

INSERT INTO @results
SELECT 'bi.fact_order_items_row_count', '111752', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 111752 THEN 'PASS' ELSE 'FAIL' END
FROM bi.fact_order_items;

INSERT INTO @results
SELECT 'bi.cohort_retention_row_count', '210', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 210 THEN 'PASS' ELSE 'FAIL' END
FROM bi.cohort_retention;

INSERT INTO @results
SELECT 'bi.cohort_pre2017_row_count', '1', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM bi.cohort_pre2017;

-- -------------------------------------------------------------------------------
-- Heatmap view excludes sentinel
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'bi.cohort_retention_no_sentinel', '0', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM bi.cohort_retention WHERE cohort_month = 'pre-2017';

-- -------------------------------------------------------------------------------
-- Slimness: no datetime columns in either fact view
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'bi.fact_orders_no_datetime', '0', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bi' AND TABLE_NAME = 'fact_orders'
  AND DATA_TYPE IN ('datetime2','datetime','date','time');

INSERT INTO @results
SELECT 'bi.fact_order_items_no_datetime', '0', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bi' AND TABLE_NAME = 'fact_order_items'
  AND DATA_TYPE IN ('datetime2','datetime','date','time');

-- -------------------------------------------------------------------------------
-- Slimness: no unexpected text columns (order_status allowed)
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'bi.fact_orders_no_natural_keys', '0', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bi' AND TABLE_NAME = 'fact_orders'
  AND DATA_TYPE IN ('nvarchar','varchar')
  AND COLUMN_NAME <> 'order_status';

INSERT INTO @results
SELECT 'bi.fact_order_items_no_natural_keys', '0', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bi' AND TABLE_NAME = 'fact_order_items'
  AND DATA_TYPE IN ('nvarchar','varchar')
  AND COLUMN_NAME <> 'order_status';

-- -------------------------------------------------------------------------------
-- RFM merged into dim_customer
-- -------------------------------------------------------------------------------
INSERT INTO @results
SELECT 'bi.dim_customer_has_rfm_columns', '6', CAST(COUNT(*) AS NVARCHAR(50)),
       CASE WHEN COUNT(*) = 6 THEN 'PASS' ELSE 'FAIL' END
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'bi' AND TABLE_NAME = 'dim_customer'
  AND COLUMN_NAME IN ('recency_days','frequency','monetary','r_score','f_band','m_score');

-- -------------------------------------------------------------------------------
-- Show / throw
-- -------------------------------------------------------------------------------
SELECT test_name, expected, actual, status FROM @results ORDER BY test_id;

SELECT
    SUM(CASE WHEN status = 'PASS' THEN 1 ELSE 0 END) AS passed,
    SUM(CASE WHEN status = 'FAIL' THEN 1 ELSE 0 END) AS failed,
    COUNT(*) AS total
FROM @results;

IF EXISTS (SELECT 1 FROM @results WHERE status = 'FAIL')
    THROW 51000, 'One or more bi-view tests failed.', 1;

PRINT 'All bi-view tests passed.';
GO