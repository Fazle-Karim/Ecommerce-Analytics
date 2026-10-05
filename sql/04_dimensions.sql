-- ===============================================================================
-- Script: 04_dimensions.sql
-- Purpose: Build the analytics dimension tables on top of the clean layer.
--          Dimensions are built BEFORE facts; facts reference their keys.
--          Facts and dims are restricted to the analytic population (97,905 orders).
-- Run order: after 03_cleaning.sql.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

-- -------------------------------------------------------------------------------
-- 1. Analytics schema + build log
-- -------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO

IF OBJECT_ID('analytics.build_log', 'U') IS NULL
BEGIN
    CREATE TABLE analytics.build_log (
        log_id          INT IDENTITY(1,1) PRIMARY KEY,
        run_id          INT             NOT NULL,
        step_id         NVARCHAR(50)    NOT NULL,
        step_description NVARCHAR(200)  NOT NULL,
        object_name     NVARCHAR(100)   NOT NULL,
        rows_written    INT             NOT NULL,
        build_applied_at DATETIME2      NOT NULL DEFAULT SYSUTCDATETIME()
    );
END
GO

IF OBJECT_ID('tempdb..#analytics_run_ctx') IS NOT NULL DROP TABLE #analytics_run_ctx;
CREATE TABLE #analytics_run_ctx (run_id INT NOT NULL);
INSERT INTO #analytics_run_ctx (run_id)
SELECT ISNULL(MAX(run_id), 0) + 1 FROM analytics.build_log;

DECLARE @run_id INT = (SELECT run_id FROM #analytics_run_ctx);
PRINT 'Analytics layer run_id = ' + CAST(@run_id AS NVARCHAR(10));
GO

IF OBJECT_ID('analytics.usp_log_build', 'P') IS NOT NULL
    DROP PROCEDURE analytics.usp_log_build;
GO

CREATE PROCEDURE analytics.usp_log_build
    @step_id            NVARCHAR(50),
    @step_description   NVARCHAR(200),
    @object_name        NVARCHAR(100),
    @rows_written       INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @run_id INT = (SELECT run_id FROM #analytics_run_ctx);
    INSERT INTO analytics.build_log
        (run_id, step_id, step_description, object_name, rows_written)
    VALUES
        (@run_id, @step_id, @step_description, @object_name, @rows_written);
END
GO

-- ===============================================================================
-- SECTION 1: dim_date
-- ===============================================================================

IF OBJECT_ID('analytics.dim_date', 'U') IS NOT NULL DROP TABLE analytics.dim_date;

CREATE TABLE analytics.dim_date (
    date_key        INT           NOT NULL PRIMARY KEY,   -- yyyymmdd
    full_date       DATE          NOT NULL,
    year            INT           NOT NULL,
    quarter         INT           NOT NULL,
    month           INT           NOT NULL,
    month_name      NVARCHAR(20)  NOT NULL,
    week_of_year    INT           NOT NULL,
    day_of_week     INT           NOT NULL,   -- 1 = Sunday ... 7 = Saturday
    day_name        NVARCHAR(20)  NOT NULL,
    is_in_window    BIT           NOT NULL,
    is_complete_month BIT         NOT NULL,
    is_jan_aug      BIT           NOT NULL
);

;WITH date_range AS (
    SELECT CAST('2016-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d)
    FROM date_range
    WHERE d < '2018-12-31'
)
INSERT INTO analytics.dim_date
    (date_key, full_date, year, quarter, month, month_name,
     week_of_year, day_of_week, day_name,
     is_in_window, is_complete_month, is_jan_aug)
SELECT
    CAST(CONVERT(NVARCHAR(8), d, 112) AS INT) AS date_key,
    d,
    YEAR(d),
    DATEPART(QUARTER, d),
    MONTH(d),
    DATENAME(MONTH, d),
    DATEPART(ISO_WEEK, d),
    DATEPART(WEEKDAY, d),
    DATENAME(WEEKDAY, d),
    CASE
        WHEN d >= '2017-01-01' AND d < '2018-09-01' THEN 1
        ELSE 0
    END,
    CASE
        WHEN d < '2017-01-01' THEN 0
        WHEN d >= '2018-09-01' THEN 0
        ELSE 1
    END,
    CASE
        WHEN d >= '2017-01-01' AND d < '2018-09-01'
         AND MONTH(d) BETWEEN 1 AND 8 THEN 1
        ELSE 0
    END
FROM date_range
OPTION (MAXRECURSION 2000);

DECLARE @dd_count INT = (SELECT COUNT(*) FROM analytics.dim_date);
EXEC analytics.usp_log_build
    @step_id          = 'DIM_DATE_BUILD',
    @step_description = 'Continuous date range 2016-01-01 to 2018-12-31 with flags',
    @object_name      = 'analytics.dim_date',
    @rows_written     = @dd_count;
GO

PRINT 'analytics.dim_date built.';
GO

-- ===============================================================================
-- SECTION 2: dim_customer
-- ===============================================================================

IF OBJECT_ID('analytics.dim_customer', 'U') IS NOT NULL DROP TABLE analytics.dim_customer;

CREATE TABLE analytics.dim_customer (
    customer_key              INT IDENTITY(1,1) PRIMARY KEY,
    customer_unique_id        NVARCHAR(50)  NOT NULL UNIQUE,
    customer_zip_code_prefix  NVARCHAR(5)   NOT NULL,
    customer_city             NVARCHAR(100) NOT NULL,
    customer_state            NVARCHAR(2)   NOT NULL,
    geolocation_lat           DECIMAL(10,6) NULL,
    geolocation_lng           DECIMAL(10,6) NULL,
    coordinates_missing       BIT           NOT NULL DEFAULT 0
);

;WITH population AS (
    SELECT
        c.customer_unique_id,
        c.customer_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp DESC, c.customer_id ASC
        ) AS rn
    FROM clean.orders o
    JOIN clean.customers c ON c.customer_id = o.customer_id
    WHERE o.order_status IN ('delivered','shipped','invoiced','processing','approved')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
)
INSERT INTO analytics.dim_customer
    (customer_unique_id, customer_zip_code_prefix, customer_city, customer_state,
     geolocation_lat, geolocation_lng, coordinates_missing)
SELECT
    p.customer_unique_id,
    p.customer_zip_code_prefix,
    p.customer_city,
    p.customer_state,
    g.geolocation_lat_avg,
    g.geolocation_lng_avg,
    CASE WHEN g.geolocation_lat_avg IS NULL THEN 1 ELSE 0 END
FROM population p
LEFT JOIN clean.geolocation g
    ON g.geolocation_zip_code_prefix = p.customer_zip_code_prefix
WHERE p.rn = 1;

DECLARE @dc_count INT = (SELECT COUNT(*) FROM analytics.dim_customer);
EXEC analytics.usp_log_build
    @step_id          = 'DIM_CUSTOMER_BUILD',
    @step_description = 'One row per customer_unique_id in analytic population; latest order wins',
    @object_name      = 'analytics.dim_customer',
    @rows_written     = @dc_count;
GO

PRINT 'analytics.dim_customer built.';
GO

-- ===============================================================================
-- SECTION 3: dim_product
-- ===============================================================================

IF OBJECT_ID('analytics.dim_product', 'U') IS NOT NULL DROP TABLE analytics.dim_product;

CREATE TABLE analytics.dim_product (
    product_key                INT IDENTITY(1,1) PRIMARY KEY,
    product_id                 NVARCHAR(50)  NOT NULL UNIQUE,
    product_category_name      NVARCHAR(100) NOT NULL,
    category_name_english      NVARCHAR(100) NOT NULL,
    category_display_name      NVARCHAR(100) NOT NULL,
    product_name_length        INT           NULL,
    product_description_length INT           NULL,
    product_photos_qty         INT           NULL,
    product_weight_g           INT           NULL,
    product_length_cm          INT           NULL,
    product_height_cm          INT           NULL,
    product_width_cm           INT           NULL,
    flag_missing_dimensions    BIT           NOT NULL
);

INSERT INTO analytics.dim_product
    (product_id, product_category_name, category_name_english, category_display_name,
     product_name_length, product_description_length, product_photos_qty,
     product_weight_g, product_length_cm, product_height_cm, product_width_cm,
     flag_missing_dimensions)
SELECT DISTINCT
    p.product_id,
    p.product_category_name,
    p.category_name_english,
    p.category_display_name,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.flag_missing_dimensions
FROM clean.products p
WHERE p.product_id IN (
    SELECT DISTINCT oi.product_id
    FROM clean.order_items oi
    JOIN clean.orders o ON o.order_id = oi.order_id
    WHERE o.order_status IN ('delivered','shipped','invoiced','processing','approved')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
);

DECLARE @dp_count INT = (SELECT COUNT(*) FROM analytics.dim_product);
EXEC analytics.usp_log_build
    @step_id          = 'DIM_PRODUCT_BUILD',
    @step_description = 'One row per product_id in analytic fact_order_items',
    @object_name      = 'analytics.dim_product',
    @rows_written     = @dp_count;
GO

PRINT 'analytics.dim_product built.';
GO

-- ===============================================================================
-- SECTION 4: dim_seller
-- ===============================================================================

IF OBJECT_ID('analytics.dim_seller', 'U') IS NOT NULL DROP TABLE analytics.dim_seller;

CREATE TABLE analytics.dim_seller (
    seller_key                INT IDENTITY(1,1) PRIMARY KEY,
    seller_id                 NVARCHAR(50)  NOT NULL UNIQUE,
    seller_zip_code_prefix    NVARCHAR(5)   NOT NULL,
    seller_city               NVARCHAR(100) NOT NULL,
    seller_state              NVARCHAR(2)   NOT NULL,
    geolocation_lat           DECIMAL(10,6) NULL,
    geolocation_lng           DECIMAL(10,6) NULL,
    coordinates_missing       BIT           NOT NULL DEFAULT 0
);

INSERT INTO analytics.dim_seller
    (seller_id, seller_zip_code_prefix, seller_city, seller_state,
     geolocation_lat, geolocation_lng, coordinates_missing)
SELECT DISTINCT
    s.seller_id,
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,
    g.geolocation_lat_avg,
    g.geolocation_lng_avg,
    CASE WHEN g.geolocation_lat_avg IS NULL THEN 1 ELSE 0 END
FROM clean.sellers s
LEFT JOIN clean.geolocation g
    ON g.geolocation_zip_code_prefix = s.seller_zip_code_prefix
WHERE s.seller_id IN (
    SELECT DISTINCT oi.seller_id
    FROM clean.order_items oi
    JOIN clean.orders o ON o.order_id = oi.order_id
    WHERE o.order_status IN ('delivered','shipped','invoiced','processing','approved')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
);

DECLARE @ds_count INT = (SELECT COUNT(*) FROM analytics.dim_seller);
EXEC analytics.usp_log_build
    @step_id          = 'DIM_SELLER_BUILD',
    @step_description = 'One row per seller_id in analytic fact_order_items',
    @object_name      = 'analytics.dim_seller',
    @rows_written     = @ds_count;
GO

PRINT 'analytics.dim_seller built.';
GO

-- ===============================================================================
-- SECTION 5: Verify
-- ===============================================================================

SELECT 'analytics.dim_date'     AS table_name, COUNT(*) AS rows FROM analytics.dim_date
UNION ALL SELECT 'analytics.dim_customer',  COUNT(*) FROM analytics.dim_customer
UNION ALL SELECT 'analytics.dim_product',   COUNT(*) FROM analytics.dim_product
UNION ALL SELECT 'analytics.dim_seller',    COUNT(*) FROM analytics.dim_seller;
GO

SELECT
    MIN(full_date) AS min_date,
    MAX(full_date) AS max_date,
    SUM(CAST(is_in_window AS INT)) AS in_window_days,
    SUM(CAST(is_complete_month AS INT)) AS complete_month_days,
    SUM(CAST(is_jan_aug AS INT)) AS jan_aug_days
FROM analytics.dim_date;
GO

SELECT
    COUNT(*) AS total_customers,
    SUM(CAST(coordinates_missing AS INT)) AS customers_without_coords
FROM analytics.dim_customer;
GO

SELECT
    COUNT(*) AS total_sellers,
    SUM(CAST(coordinates_missing AS INT)) AS sellers_without_coords
FROM analytics.dim_seller;
GO

SELECT step_id, object_name, rows_written
FROM analytics.build_log
WHERE run_id = (SELECT MAX(run_id) FROM analytics.build_log)
ORDER BY log_id;
GO