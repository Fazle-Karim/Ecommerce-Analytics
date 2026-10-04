-- ===============================================================================
-- Script: 02_load_raw.sql
-- Purpose: Load all 9 Olist CSVs into the raw schema.
--          Re-runnable: TRUNCATEs every raw table before loading.
--          Logs row counts into raw.load_log.
-- Notes:   The Olist CSVs use mixed line endings:
--            - 7 files are LF-only (\n)      → ROWTERMINATOR = '0x0a'
--            - 2 files are CRLF   (\r\n)     → default
--          All columns load as text (NVARCHAR). Type casting happens in Step 4.
-- ===============================================================================

USE OlistAnalytics;
GO

-- -------------------------------------------------------------------------------
-- 1. Drop and recreate the load log table
-- -------------------------------------------------------------------------------
IF OBJECT_ID('raw.load_log', 'U') IS NOT NULL
    DROP TABLE raw.load_log;
GO

CREATE TABLE raw.load_log (
    load_id          INT IDENTITY(1,1) PRIMARY KEY,
    table_name       NVARCHAR(50)   NOT NULL,
    row_count        INT            NOT NULL,
    load_timestamp   DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME(),
    source_file      NVARCHAR(200)  NOT NULL
);
GO

-- -------------------------------------------------------------------------------
-- 2. Truncate every raw table so the script is re-runnable
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
-- 3. BULK INSERT each CSV
-- -------------------------------------------------------------------------------

-- 3.1 orders  (LF-only)
BULK INSERT raw.orders
FROM 'C:\data\olist\olist_orders_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'orders', COUNT(*), 'olist_orders_dataset.csv' FROM raw.orders;
GO

-- 3.2 order_items  (LF-only)
BULK INSERT raw.order_items
FROM 'C:\data\olist\olist_order_items_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'order_items', COUNT(*), 'olist_order_items_dataset.csv' FROM raw.order_items;
GO

-- 3.3 payments  (LF-only)
BULK INSERT raw.payments
FROM 'C:\data\olist\olist_order_payments_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'payments', COUNT(*), 'olist_order_payments_dataset.csv' FROM raw.payments;
GO

-- 3.4 reviews  (CRLF — default terminator)
BULK INSERT raw.reviews
FROM 'C:\data\olist\olist_order_reviews_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'reviews', COUNT(*), 'olist_order_reviews_dataset.csv' FROM raw.reviews;
GO

-- 3.5 customers  (LF-only)
BULK INSERT raw.customers
FROM 'C:\data\olist\olist_customers_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'customers', COUNT(*), 'olist_customers_dataset.csv' FROM raw.customers;
GO

-- 3.6 sellers  (LF-only)
BULK INSERT raw.sellers
FROM 'C:\data\olist\olist_sellers_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'sellers', COUNT(*), 'olist_sellers_dataset.csv' FROM raw.sellers;
GO

-- 3.7 products  (LF-only)
BULK INSERT raw.products
FROM 'C:\data\olist\olist_products_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'products', COUNT(*), 'olist_products_dataset.csv' FROM raw.products;
GO

-- 3.8 geolocation  (LF-only)
BULK INSERT raw.geolocation
FROM 'C:\data\olist\olist_geolocation_dataset.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0a',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'geolocation', COUNT(*), 'olist_geolocation_dataset.csv' FROM raw.geolocation;
GO

-- 3.9 category_translation  (CRLF — default terminator)
BULK INSERT raw.category_translation
FROM 'C:\data\olist\product_category_name_translation.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    TABLOCK
);
GO
INSERT INTO raw.load_log (table_name, row_count, source_file)
SELECT 'category_translation', COUNT(*), 'product_category_name_translation.csv' FROM raw.category_translation;
GO

PRINT 'All raw tables loaded.';
GO

-- -------------------------------------------------------------------------------
-- 4. Display the load log
-- -------------------------------------------------------------------------------
SELECT
    table_name,
    row_count,
    load_timestamp,
    source_file
FROM raw.load_log
ORDER BY table_name;
GO