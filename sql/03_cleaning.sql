-- ===============================================================================
-- Script: 03_cleaning.sql
-- Purpose: Build the clean layer (typed, standardized, flagged).
--          Derived metrics belong in analytics, not here.
-- Run order: cleaned tables are built from raw.* after 02_load_raw.sql.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

-- -------------------------------------------------------------------------------
-- 1. Clean schema guard
-- -------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'clean')
    EXEC('CREATE SCHEMA clean');
GO

-- -------------------------------------------------------------------------------
-- 2. clean.cleaning_log — append-only audit trail of every rule applied
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.cleaning_log', 'U') IS NULL
BEGIN
    CREATE TABLE clean.cleaning_log (
        log_id              INT IDENTITY(1,1) PRIMARY KEY,
        run_id              INT             NOT NULL,
        rule_id             NVARCHAR(50)    NOT NULL,
        rule_description    NVARCHAR(200)   NOT NULL,
        table_name          NVARCHAR(50)    NOT NULL,
        rows_in             INT             NOT NULL,
        rows_out            INT             NOT NULL,
        rows_flagged        INT             NOT NULL DEFAULT 0,
        rule_applied_at     DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
GO

-- -------------------------------------------------------------------------------
-- 3. Run context — one run_id per execution, shared across batches
-- -------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#clean_run_ctx') IS NOT NULL DROP TABLE #clean_run_ctx;
CREATE TABLE #clean_run_ctx (run_id INT NOT NULL);

INSERT INTO #clean_run_ctx (run_id)
SELECT ISNULL(MAX(run_id), 0) + 1 FROM clean.cleaning_log;

DECLARE @run_id INT = (SELECT run_id FROM #clean_run_ctx);
PRINT 'Clean layer run_id = ' + CAST(@run_id AS NVARCHAR(10));
GO

-- -------------------------------------------------------------------------------
-- 4. Helper: append a rule log entry for this run
--    Used by every subsequent cleaning block.
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.usp_log_rule', 'P') IS NOT NULL
    DROP PROCEDURE clean.usp_log_rule;
GO

CREATE PROCEDURE clean.usp_log_rule
    @rule_id            NVARCHAR(50),
    @rule_description   NVARCHAR(200),
    @table_name         NVARCHAR(50),
    @rows_in            INT,
    @rows_out           INT,
    @rows_flagged       INT = 0
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @run_id INT = (SELECT run_id FROM #clean_run_ctx);
    INSERT INTO clean.cleaning_log
        (run_id, rule_id, rule_description, table_name,
         rows_in, rows_out, rows_flagged)
    VALUES
        (@run_id, @rule_id, @rule_description, @table_name,
         @rows_in, @rows_out, @rows_flagged);
END
GO

PRINT 'Clean infrastructure ready.';
GO

-- -------------------------------------------------------------------------------
-- 5. Verify
-- -------------------------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM clean.cleaning_log) AS log_rows,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES
     WHERE TABLE_SCHEMA = 'clean' AND TABLE_NAME = 'cleaning_log') AS log_table_exists,
    (SELECT COUNT(*) FROM INFORMATION_SCHEMA.ROUTINES
     WHERE ROUTINE_SCHEMA = 'clean' AND ROUTINE_NAME = 'usp_log_rule') AS proc_exists;
GO

-- ===============================================================================
-- SECTION 2: Geography tables
-- ===============================================================================

-- -------------------------------------------------------------------------------
-- 2.1 Normalize zip prefixes (5 digits, zero-padded) — resolve ambiguity
-- -------------------------------------------------------------------------------
-- First, confirm the length distribution. If any prefix has < 5 chars, pad it.
-- We handle all three tables identically so joins don't silently fail.

-- -------------------------------------------------------------------------------
-- 2.2 clean.customers
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.customers', 'U') IS NOT NULL DROP TABLE clean.customers;

CREATE TABLE clean.customers (
    customer_id                 NVARCHAR(50)  NOT NULL,
    customer_unique_id          NVARCHAR(50)  NOT NULL,
    customer_zip_code_prefix    NVARCHAR(5)   NOT NULL,
    customer_city               NVARCHAR(100) NOT NULL,
    customer_state              NVARCHAR(2)   NOT NULL
);

INSERT INTO clean.customers
    (customer_id, customer_unique_id, customer_zip_code_prefix,
     customer_city, customer_state)
SELECT
    customer_id,
    customer_unique_id,
    RIGHT('00000' + LTRIM(RTRIM(customer_zip_code_prefix)), 5),
    LOWER(LTRIM(RTRIM(customer_city))),
    UPPER(LTRIM(RTRIM(customer_state)))
FROM raw.customers;

DECLARE @cust_in  INT = (SELECT COUNT(*) FROM raw.customers);
DECLARE @cust_out INT = (SELECT COUNT(*) FROM clean.customers);
EXEC clean.usp_log_rule
    @rule_id          = 'CUSTOMERS_TYPED',
    @rule_description = 'Type cast and normalize zip (5-digit pad), city (lower), state (upper)',
    @table_name       = 'customers',
    @rows_in          = @cust_in,
    @rows_out         = @cust_out,
    @rows_flagged     = 0;
GO

PRINT 'clean.customers built.';
GO

-- -------------------------------------------------------------------------------
-- 2.3 clean.sellers
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.sellers', 'U') IS NOT NULL DROP TABLE clean.sellers;

CREATE TABLE clean.sellers (
    seller_id                   NVARCHAR(50)  NOT NULL,
    seller_zip_code_prefix      NVARCHAR(5)   NOT NULL,
    seller_city                 NVARCHAR(100) NOT NULL,
    seller_state                NVARCHAR(2)   NOT NULL
);

INSERT INTO clean.sellers
    (seller_id, seller_zip_code_prefix, seller_city, seller_state)
SELECT
    seller_id,
    RIGHT('00000' + LTRIM(RTRIM(seller_zip_code_prefix)), 5),
    LOWER(LTRIM(RTRIM(seller_city))),
    UPPER(LTRIM(RTRIM(seller_state)))
FROM raw.sellers;

DECLARE @sell_in  INT = (SELECT COUNT(*) FROM raw.sellers);
DECLARE @sell_out INT = (SELECT COUNT(*) FROM clean.sellers);
EXEC clean.usp_log_rule
    @rule_id          = 'SELLERS_TYPED',
    @rule_description = 'Type cast and normalize zip (5-digit pad), city (lower), state (upper)',
    @table_name       = 'sellers',
    @rows_in          = @sell_in,
    @rows_out         = @sell_out,
    @rows_flagged     = 0;
GO

PRINT 'clean.sellers built.';
GO

-- -------------------------------------------------------------------------------
-- 2.4 clean.geolocation
--    Aggregate to one row per zip prefix, averaging lat/lng.
--    --    Filter coordinates outside Brazil's bounding box (-34.0 to 5.5 lat, -74.0 to -32.0 lng).
--    The eastern edge is -32.0 (not -34.0) to include Fernando de Noronha at ~-32.42 lng,
--    which is legitimately Brazilian.
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.geolocation', 'U') IS NOT NULL DROP TABLE clean.geolocation;

CREATE TABLE clean.geolocation (
    geolocation_zip_code_prefix    NVARCHAR(5)    NOT NULL PRIMARY KEY,
    geolocation_lat_avg            DECIMAL(10,6)  NOT NULL,
    geolocation_lng_avg            DECIMAL(10,6)  NOT NULL,
    geolocation_city               NVARCHAR(100)  NULL,
    geolocation_state              NVARCHAR(2)    NULL,
    sample_count                   INT            NOT NULL,
    filtered_count                 INT            NOT NULL DEFAULT 0
);

;WITH normalized AS (
    SELECT
        RIGHT('00000' + LTRIM(RTRIM(geolocation_zip_code_prefix)), 5) AS zip5,
        TRY_CAST(geolocation_lat AS DECIMAL(10,6)) AS lat,
        TRY_CAST(geolocation_lng AS DECIMAL(10,6)) AS lng,
        LOWER(LTRIM(RTRIM(geolocation_city)))      AS city,
        UPPER(LTRIM(RTRIM(geolocation_state)))     AS state
    FROM raw.geolocation
),
filtered AS (
    SELECT
        zip5, lat, lng, city, state,
        CASE
            WHEN lat IS NULL OR lng IS NULL THEN 1
            WHEN lat < -34.0 OR lat > 5.5 OR lng < -74.0 OR lng > -32.0 THEN 1
            ELSE 0
        END AS is_outside
    FROM normalized
),
aggregated AS (
    SELECT
        zip5,
        AVG(CASE WHEN is_outside = 0 THEN lat END) AS lat_avg,
        AVG(CASE WHEN is_outside = 0 THEN lng END) AS lng_avg,
        MAX(city)  AS city,
        MAX(state) AS state,
        SUM(CASE WHEN is_outside = 0 THEN 1 ELSE 0 END) AS sample_count,
        SUM(is_outside) AS filtered_count
    FROM filtered
    GROUP BY zip5
)
INSERT INTO clean.geolocation
    (geolocation_zip_code_prefix, geolocation_lat_avg, geolocation_lng_avg,
     geolocation_city, geolocation_state, sample_count, filtered_count)
SELECT
    zip5, lat_avg, lng_avg, city, state, sample_count, filtered_count
FROM aggregated
WHERE lat_avg IS NOT NULL AND lng_avg IS NOT NULL;

DECLARE @geo_in       INT = (SELECT COUNT(*) FROM raw.geolocation);
DECLARE @geo_out      INT = (SELECT COUNT(*) FROM clean.geolocation);
DECLARE @geo_filtered INT = (SELECT ISNULL(SUM(filtered_count), 0) FROM clean.geolocation);
DECLARE @geo_dropped  INT = @geo_in - (SELECT ISNULL(SUM(sample_count + filtered_count), 0) FROM clean.geolocation);

EXEC clean.usp_log_rule
    @rule_id          = 'GEOLOCATION_DEDUP',
    @rule_description = 'Aggregate to one row per zip; filter coordinates outside Brazil bbox',
    @table_name       = 'geolocation',
    @rows_in          = @geo_in,
    @rows_out         = @geo_out,
    @rows_flagged     = @geo_filtered;
GO
-- Log the prefixes entirely dropped (all coordinates outside Brazil bbox)
DECLARE @dropped_prefixes INT = (
    SELECT COUNT(DISTINCT RIGHT('00000' + LTRIM(RTRIM(r.geolocation_zip_code_prefix)), 5))
    FROM raw.geolocation r
    WHERE NOT EXISTS (
        SELECT 1 FROM clean.geolocation c
        WHERE c.geolocation_zip_code_prefix =
              RIGHT('00000' + LTRIM(RTRIM(r.geolocation_zip_code_prefix)), 5)
    )
);

EXEC clean.usp_log_rule
    @rule_id          = 'GEOLOCATION_DROPPED_PREFIXES',
    @rule_description = 'Zip prefixes excluded: all coordinates outside Brazil bounding box',
    @table_name       = 'geolocation',
    @rows_in          = @dropped_prefixes,
    @rows_out         = 0,
    @rows_flagged     = @dropped_prefixes;
GO
PRINT 'clean.geolocation built.';
GO

-- -------------------------------------------------------------------------------
-- 2.5 Verify
-- -------------------------------------------------------------------------------
SELECT 'clean.customers'   AS table_name, COUNT(*) AS rows FROM clean.customers
UNION ALL SELECT 'clean.sellers',      COUNT(*) FROM clean.sellers
UNION ALL SELECT 'clean.geolocation',  COUNT(*) FROM clean.geolocation;
GO

SELECT rule_id, table_name, rows_in, rows_out, rows_flagged
FROM clean.cleaning_log
ORDER BY log_id;
GO

-- ===============================================================================
-- SECTION 3: Transaction tables
-- ===============================================================================

-- -------------------------------------------------------------------------------
-- 3.1 clean.orders
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.orders', 'U') IS NOT NULL DROP TABLE clean.orders;

CREATE TABLE clean.orders (
    order_id                        NVARCHAR(50)  NOT NULL,
    customer_id                     NVARCHAR(50)  NOT NULL,
    order_status                    NVARCHAR(50)  NOT NULL,
    order_purchase_timestamp        DATETIME2     NULL,
    order_approved_at               DATETIME2     NULL,
    order_delivered_carrier_date    DATETIME2     NULL,
    order_delivered_customer_date   DATETIME2     NULL,
    order_estimated_delivery_date   DATETIME2     NULL
);

INSERT INTO clean.orders
    (order_id, customer_id, order_status,
     order_purchase_timestamp, order_approved_at,
     order_delivered_carrier_date, order_delivered_customer_date,
     order_estimated_delivery_date)
SELECT
    order_id,
    customer_id,
    LOWER(LTRIM(RTRIM(order_status))),
    TRY_CONVERT(DATETIME2, order_purchase_timestamp),
    TRY_CONVERT(DATETIME2, order_approved_at),
    TRY_CONVERT(DATETIME2, order_delivered_carrier_date),
    TRY_CONVERT(DATETIME2, order_delivered_customer_date),
    TRY_CONVERT(DATETIME2, order_estimated_delivery_date)
FROM raw.orders;

DECLARE @ord_in  INT = (SELECT COUNT(*) FROM raw.orders);
DECLARE @ord_out INT = (SELECT COUNT(*) FROM clean.orders);
EXEC clean.usp_log_rule
    @rule_id          = 'ORDERS_TYPED',
    @rule_description = 'Type cast timestamps to DATETIME2, lower status',
    @table_name       = 'orders',
    @rows_in          = @ord_in,
    @rows_out         = @ord_out,
    @rows_flagged     = 0;
GO

PRINT 'clean.orders built.';
GO

-- -------------------------------------------------------------------------------
-- 3.2 clean.order_items
--    Includes a flag for shipping_limit_date > 2018-12-31 (4 known anomalies).
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.order_items', 'U') IS NOT NULL DROP TABLE clean.order_items;

CREATE TABLE clean.order_items (
    order_id            NVARCHAR(50)  NOT NULL,
    order_item_id       INT           NOT NULL,
    product_id          NVARCHAR(50)  NOT NULL,
    seller_id           NVARCHAR(50)  NOT NULL,
    shipping_limit_date DATETIME2     NULL,
    price               DECIMAL(18,2) NULL,
    freight_value       DECIMAL(18,2) NULL,
    flag_shipping_limit_anomaly BIT NOT NULL DEFAULT 0
);

INSERT INTO clean.order_items
    (order_id, order_item_id, product_id, seller_id,
     shipping_limit_date, price, freight_value,
     flag_shipping_limit_anomaly)
SELECT
    order_id,
    TRY_CONVERT(INT, order_item_id),
    product_id,
    seller_id,
    TRY_CONVERT(DATETIME2, shipping_limit_date),
    TRY_CONVERT(DECIMAL(18,2), price),
    TRY_CONVERT(DECIMAL(18,2), freight_value),
    CASE
        WHEN TRY_CONVERT(DATETIME2, shipping_limit_date) > '2018-12-31' THEN 1
        ELSE 0
    END
FROM raw.order_items;

DECLARE @oi_in       INT = (SELECT COUNT(*) FROM raw.order_items);
DECLARE @oi_out      INT = (SELECT COUNT(*) FROM clean.order_items);
DECLARE @oi_flagged  INT = (SELECT COUNT(*) FROM clean.order_items WHERE flag_shipping_limit_anomaly = 1);
EXEC clean.usp_log_rule
    @rule_id          = 'ORDER_ITEMS_TYPED',
    @rule_description = 'Type cast IDs/amounts/timestamps; flag shipping_limit_date > 2018-12-31',
    @table_name       = 'order_items',
    @rows_in          = @oi_in,
    @rows_out         = @oi_out,
    @rows_flagged     = @oi_flagged;
GO

PRINT 'clean.order_items built.';
GO

-- -------------------------------------------------------------------------------
-- 3.3 clean.payments
--    Keeps raw grain (one row per payment). Aggregation to order level happens
--    in analytics. Rule flag: not_defined payment_type (3 known rows).
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.payments', 'U') IS NOT NULL DROP TABLE clean.payments;

CREATE TABLE clean.payments (
    order_id                NVARCHAR(50)  NOT NULL,
    payment_sequential      INT           NOT NULL,
    payment_type            NVARCHAR(50)  NOT NULL,
    payment_installments    INT           NULL,
    payment_value           DECIMAL(18,2) NULL,
    flag_undefined_type     BIT           NOT NULL DEFAULT 0
);

INSERT INTO clean.payments
    (order_id, payment_sequential, payment_type,
     payment_installments, payment_value,
     flag_undefined_type)
SELECT
    order_id,
    TRY_CONVERT(INT, payment_sequential),
    LOWER(LTRIM(RTRIM(payment_type))),
    TRY_CONVERT(INT, payment_installments),
    TRY_CONVERT(DECIMAL(18,2), payment_value),
    CASE WHEN LOWER(LTRIM(RTRIM(payment_type))) = 'not_defined' THEN 1 ELSE 0 END
FROM raw.payments;

DECLARE @pay_in       INT = (SELECT COUNT(*) FROM raw.payments);
DECLARE @pay_out      INT = (SELECT COUNT(*) FROM clean.payments);
DECLARE @pay_flagged  INT = (SELECT COUNT(*) FROM clean.payments WHERE flag_undefined_type = 1);
EXEC clean.usp_log_rule
    @rule_id          = 'PAYMENTS_TYPED',
    @rule_description = 'Type cast sequential/installments/amount; flag not_defined payment_type',
    @table_name       = 'payments',
    @rows_in          = @pay_in,
    @rows_out         = @pay_out,
    @rows_flagged     = @pay_flagged;
GO

PRINT 'clean.payments built.';
GO

-- -------------------------------------------------------------------------------
-- 3.4 Verify
-- -------------------------------------------------------------------------------
SELECT 'clean.orders'        AS table_name, COUNT(*) AS rows FROM clean.orders
UNION ALL SELECT 'clean.order_items',       COUNT(*) FROM clean.order_items
UNION ALL SELECT 'clean.payments',          COUNT(*) FROM clean.payments;
GO

-- Flag counts
SELECT
    (SELECT COUNT(*) FROM clean.order_items WHERE flag_shipping_limit_anomaly = 1) AS order_items_shipping_anomalies,
    (SELECT COUNT(*) FROM clean.payments    WHERE flag_undefined_type = 1)          AS payments_undefined_type;
GO

-- Latest run's log
SELECT rule_id, table_name, rows_in, rows_out, rows_flagged
FROM clean.cleaning_log
WHERE run_id = (SELECT MAX(run_id) FROM clean.cleaning_log)
ORDER BY log_id;
GO