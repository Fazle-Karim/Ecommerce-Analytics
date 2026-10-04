-- ===============================================================================
-- Script: 02_load_raw.sql
-- Purpose: Load all 9 Olist CSVs into the raw schema.
--          Re-runnable: TRUNCATEs every raw table before loading.
--          Appends row counts to raw.load_log with a run_id.
--          Fails loudly on any error (SQLCMD :on error exit).
--
-- Source:  C:\data\olist\  (9 CSVs)
-- Target:  OlistAnalytics.raw (NVARCHAR columns)
--
-- Notes:   The Olist CSVs use mixed line endings:
--            - 7 files are LF-only (\n)   -> ROWTERMINATOR = '0x0a'
--            - 2 files are CRLF   (\r\n)  -> default
--          All columns load as text (NVARCHAR). Type casting happens in Step 4.
--
-- PREREQ:  SQLCMD mode must be enabled in SSMS (Query -> SQLCMD Mode).
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

-- -------------------------------------------------------------------------------
-- 1. Ensure raw.load_log exists with the run_id schema.
--    If it exists with an older schema, drop and recreate.
-- -------------------------------------------------------------------------------
IF OBJECT_ID('raw.load_log', 'U') IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE TABLE_SCHEMA='raw' AND TABLE_NAME='load_log'
                   AND COLUMN_NAME='run_id')
BEGIN
    DROP TABLE raw.load_log;
END
GO

IF OBJECT_ID('raw.load_log', 'U') IS NULL
BEGIN
    CREATE TABLE raw.load_log (
        load_id          INT IDENTITY(1,1) PRIMARY KEY,
        run_id           INT            NOT NULL,
        table_name       NVARCHAR(50)   NOT NULL,
        row_count        INT            NOT NULL,
        load_timestamp   DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
        source_file      NVARCHAR(200)  NOT NULL
    );
END
GO

-- -------------------------------------------------------------------------------
-- 2. Determine run_id for this execution and store it in a temp table so it
--    survives across GO batch boundaries.
-- -------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#run_ctx') IS NOT NULL DROP TABLE #run_ctx;

CREATE TABLE #run_ctx (run_id INT NOT NULL);

INSERT INTO #run_ctx (run_id)
SELECT ISNULL(MAX(run_id), 0) + 1 FROM raw.load_log;

DECLARE @run_id INT = (SELECT run_id FROM #run_ctx);
PRINT 'Starting load run_id = ' + CAST(@run_id AS NVARCHAR(10));
GO

-- -------------------------------------------------------------------------------
-- 3. Truncate every raw table so the script is re-runnable
-- -------------------------------------------------------------------------------
TRUNCATE TABLE raw.orders;
TRUNCATE TABLE raw.order_items;
TRUNCATE TABLE raw.payments;
TRUNCATE TABLE raw.reviews;
TRUNCATE TABLE raw.customers;
TRUNCATE TABLE raw.sellers;
TRUNCATE TABLE raw.products;
TRUNCATE TABLE raw.geolocation;
TRUNCATE TABLE raw.category_translation;
GO

PRINT 'Raw tables truncated.';
GO

-- -------------------------------------------------------------------------------
-- 4. BULK INSERT each CSV and log row count
-- -------------------------------------------------------------------------------

-- 4.1 orders  (LF-only)
BULK INSERT raw.orders
FROM 'C:\data\olist\olist_orders_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      ROWTERMINATOR = '0x0a', TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'orders', COUNT(*),
       'olist_orders_dataset.csv'
FROM raw.orders;
GO

-- 4.2 order_items  (LF-only)
BULK INSERT raw.order_items
FROM 'C:\data\olist\olist_order_items_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      ROWTERMINATOR = '0x0a', TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'order_items', COUNT(*),
       'olist_order_items_dataset.csv'
FROM raw.order_items;
GO

-- 4.3 payments  (LF-only)
BULK INSERT raw.payments
FROM 'C:\data\olist\olist_order_payments_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      ROWTERMINATOR = '0x0a', TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'payments', COUNT(*),
       'olist_order_payments_dataset.csv'
FROM raw.payments;
GO

-- 4.4 reviews  (CRLF -- default terminator)
BULK INSERT raw.reviews
FROM 'C:\data\olist\olist_order_reviews_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'reviews', COUNT(*),
       'olist_order_reviews_dataset.csv'
FROM raw.reviews;
GO

-- 4.5 customers  (LF-only)
BULK INSERT raw.customers
FROM 'C:\data\olist\olist_customers_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      ROWTERMINATOR = '0x0a', TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'customers', COUNT(*),
       'olist_customers_dataset.csv'
FROM raw.customers;
GO

-- 4.6 sellers  (LF-only)
BULK INSERT raw.sellers
FROM 'C:\data\olist\olist_sellers_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      ROWTERMINATOR = '0x0a', TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'sellers', COUNT(*),
       'olist_sellers_dataset.csv'
FROM raw.sellers;
GO

-- 4.7 products  (LF-only)
BULK INSERT raw.products
FROM 'C:\data\olist\olist_products_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      ROWTERMINATOR = '0x0a', TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'products', COUNT(*),
       'olist_products_dataset.csv'
FROM raw.products;
GO

-- 4.8 geolocation  (LF-only)
BULK INSERT raw.geolocation
FROM 'C:\data\olist\olist_geolocation_dataset.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      ROWTERMINATOR = '0x0a', TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'geolocation', COUNT(*),
       'olist_geolocation_dataset.csv'
FROM raw.geolocation;
GO

-- 4.9 category_translation  (CRLF -- default terminator)
BULK INSERT raw.category_translation
FROM 'C:\data\olist\product_category_name_translation.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDQUOTE = '"', CODEPAGE = '65001',
      TABLOCK);
GO
INSERT INTO raw.load_log (run_id, table_name, row_count, source_file)
SELECT (SELECT run_id FROM #run_ctx), 'category_translation', COUNT(*),
       'product_category_name_translation.csv'
FROM raw.category_translation;
GO

PRINT 'All raw tables loaded.';
GO

-- -------------------------------------------------------------------------------
-- 5. Expected-count assertion
-- -------------------------------------------------------------------------------
-- Expected counts below are mirrored from documentation/control_totals.json.
-- python/check_sql_literals.py verifies these literals against the JSON on
-- every run. Any mismatch there fails CI — no hand-entered values.
DECLARE @run_id_check INT = (SELECT run_id FROM #run_ctx);

DECLARE @mismatches NVARCHAR(MAX) = N'';

;WITH expected AS (
    SELECT 'category_translation' AS table_name, 71        AS expected_count
    UNION ALL SELECT 'customers',           99441
    UNION ALL SELECT 'geolocation',         1000163
    UNION ALL SELECT 'order_items',         112650
    UNION ALL SELECT 'orders',              99441
    UNION ALL SELECT 'payments',            103886
    UNION ALL SELECT 'products',            32951
    UNION ALL SELECT 'reviews',             99224
    UNION ALL SELECT 'sellers',             3095
),
actual AS (
    SELECT table_name, row_count AS actual_count
    FROM raw.load_log
    WHERE run_id = @run_id_check
)
SELECT @mismatches = @mismatches
       + e.table_name + N' expected ' + CAST(e.expected_count AS NVARCHAR(20))
       + N' got ' + CAST(ISNULL(a.actual_count, 0) AS NVARCHAR(20)) + N'; '
FROM expected e
LEFT JOIN actual a ON e.table_name = a.table_name
WHERE e.expected_count <> ISNULL(a.actual_count, 0);

IF LEN(@mismatches) > 0
BEGIN
    RAISERROR(N'Load count mismatch: %s', 16, 1, @mismatches);
END
ELSE
BEGIN
    PRINT 'All 9 tables loaded with expected row counts.';
END
GO

-- -------------------------------------------------------------------------------
-- 6. Display this run's log
-- -------------------------------------------------------------------------------
SELECT
    run_id,
    table_name,
    row_count,
    load_timestamp,
    source_file
FROM raw.load_log
WHERE run_id = (SELECT MAX(run_id) FROM raw.load_log)
ORDER BY table_name;
GO

-- -------------------------------------------------------------------------------
-- 7. Clean up temp table
-- -------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#run_ctx') IS NOT NULL DROP TABLE #run_ctx;
GO