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

-- -------------------------------------------------------------------------------
-- Helper: Title Case a string ("hello_world" -> "Hello World")
-- -------------------------------------------------------------------------------
IF OBJECT_ID('dbo.TitleCase', 'FN') IS NOT NULL
    DROP FUNCTION dbo.TitleCase;
GO

CREATE FUNCTION dbo.TitleCase (@input NVARCHAR(200))
RETURNS NVARCHAR(200)
AS
BEGIN
    DECLARE @output NVARCHAR(200) = REPLACE(LOWER(@input), '_', ' ');
    DECLARE @i INT = 1;
    DECLARE @len INT = LEN(@output);
    DECLARE @prev_was_space BIT = 1;

    WHILE @i <= @len
    BEGIN
        DECLARE @c NCHAR(1) = SUBSTRING(@output, @i, 1);
        IF @prev_was_space = 1 AND @c BETWEEN 'a' AND 'z'
        BEGIN
            SET @output = STUFF(@output, @i, 1, UPPER(@c));
        END
        SET @prev_was_space = CASE WHEN @c = ' ' THEN 1 ELSE 0 END;
        SET @i = @i + 1;
    END

    RETURN @output;
END
GO

PRINT 'Clean infrastructure ready.';
GO

-- ===============================================================================
-- SECTION 2: Geography tables
-- ===============================================================================

-- -------------------------------------------------------------------------------
-- 2.1 clean.customers
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.customers', 'U') IS NOT NULL DROP TABLE clean.customers;

CREATE TABLE clean.customers (
    customer_id                 NVARCHAR(50)  NOT NULL PRIMARY KEY,
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
-- 2.2 clean.sellers
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.sellers', 'U') IS NOT NULL DROP TABLE clean.sellers;

CREATE TABLE clean.sellers (
    seller_id                   NVARCHAR(50)  NOT NULL PRIMARY KEY,
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
-- 2.3 clean.geolocation
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.geolocation', 'U') IS NOT NULL DROP TABLE clean.geolocation;

CREATE TABLE clean.geolocation (
    geolocation_zip_code_prefix  NVARCHAR(5)    NOT NULL PRIMARY KEY,
    geolocation_lat_avg          DECIMAL(10,6)  NULL,
    geolocation_lng_avg          DECIMAL(10,6)  NULL,
    sample_count                 INT            NOT NULL,
    filtered_count               INT            NOT NULL DEFAULT 0,
    is_coordinates_missing       BIT            NOT NULL DEFAULT 0
);

;WITH normalized AS (
    SELECT
        RIGHT('00000' + LTRIM(RTRIM(geolocation_zip_code_prefix)), 5) AS zip5,
        TRY_CAST(geolocation_lat AS DECIMAL(10,6)) AS lat,
        TRY_CAST(geolocation_lng AS DECIMAL(10,6)) AS lng
    FROM raw.geolocation
),
filtered AS (
    SELECT
        zip5, lat, lng,
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
        SUM(CASE WHEN is_outside = 0 THEN 1 ELSE 0 END) AS sample_count,
        SUM(is_outside) AS filtered_count
    FROM filtered
    GROUP BY zip5
)
INSERT INTO clean.geolocation
    (geolocation_zip_code_prefix, geolocation_lat_avg, geolocation_lng_avg,
     sample_count, filtered_count, is_coordinates_missing)
SELECT
    zip5,
    lat_avg,
    lng_avg,
    sample_count,
    filtered_count,
    CASE WHEN lat_avg IS NULL OR lng_avg IS NULL THEN 1 ELSE 0 END
FROM aggregated;

DECLARE @geo_in              INT = (SELECT COUNT(*) FROM raw.geolocation);
DECLARE @geo_out             INT = (SELECT COUNT(*) FROM clean.geolocation);
DECLARE @geo_filtered        INT = (SELECT ISNULL(SUM(filtered_count), 0) FROM clean.geolocation);
DECLARE @geo_missing_coords  INT = (SELECT COUNT(*) FROM clean.geolocation WHERE is_coordinates_missing = 1);

EXEC clean.usp_log_rule
    @rule_id          = 'GEOLOCATION_DEDUP',
    @rule_description = 'Aggregate per zip; filter coords outside Brazil bbox; keep prefixes with no valid coords',
    @table_name       = 'geolocation',
    @rows_in          = @geo_in,
    @rows_out         = @geo_out,
    @rows_flagged     = @geo_filtered;

EXEC clean.usp_log_rule
    @rule_id          = 'GEOLOCATION_MISSING_COORDS',
    @rule_description = 'Zip prefixes retained with NULL coordinates (all source coords outside bbox)',
    @table_name       = 'geolocation',
    @rows_in          = @geo_missing_coords,
    @rows_out         = @geo_missing_coords,
    @rows_flagged     = @geo_missing_coords;
GO

PRINT 'clean.geolocation built.';
GO

-- ===============================================================================
-- SECTION 3: Transaction tables
-- ===============================================================================

-- -------------------------------------------------------------------------------
-- 3.1 clean.orders
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.orders', 'U') IS NOT NULL DROP TABLE clean.orders;

CREATE TABLE clean.orders (
    order_id                        NVARCHAR(50)  NOT NULL PRIMARY KEY,
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
    flag_shipping_limit_anomaly BIT NOT NULL DEFAULT 0,
    CONSTRAINT PK_order_items PRIMARY KEY (order_id, order_item_id)
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
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.payments', 'U') IS NOT NULL DROP TABLE clean.payments;

CREATE TABLE clean.payments (
    order_id                NVARCHAR(50)  NOT NULL,
    payment_sequential      INT           NOT NULL,
    payment_type            NVARCHAR(50)  NOT NULL,
    payment_installments    INT           NULL,
    payment_value           DECIMAL(18,2) NULL,
    flag_undefined_type     BIT           NOT NULL DEFAULT 0,
    CONSTRAINT PK_payments PRIMARY KEY (order_id, payment_sequential)
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

-- ===============================================================================
-- SECTION 4: Dimension tables
-- ===============================================================================

-- -------------------------------------------------------------------------------
-- 4.1 clean.category_translation
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.category_translation', 'U') IS NOT NULL DROP TABLE clean.category_translation;

CREATE TABLE clean.category_translation (
    product_category_name           NVARCHAR(100) NOT NULL PRIMARY KEY,
    product_category_name_english   NVARCHAR(100) NOT NULL,
    display_name                    NVARCHAR(100) NOT NULL,
    is_manual_override              BIT           NOT NULL DEFAULT 0
);

-- Base translations from raw (71 rows)
INSERT INTO clean.category_translation
    (product_category_name, product_category_name_english, display_name, is_manual_override)
SELECT
    LOWER(LTRIM(RTRIM(product_category_name))),
    LOWER(LTRIM(RTRIM(product_category_name_english))),
    dbo.TitleCase(LOWER(LTRIM(RTRIM(product_category_name_english)))),
    0
FROM raw.category_translation;

-- Manual overrides for missing translations (2 rows)
INSERT INTO clean.category_translation
    (product_category_name, product_category_name_english, display_name, is_manual_override)
VALUES
    ('pc_gamer', 'pc_gamer', 'PC Gamer', 1),
    ('portateis_cozinha_e_preparadores_de_alimentos',
     'kitchen_food_prep_portables',
     'Kitchen & Food Prep Portables', 1);

-- Fix 5 English typos from the source CSV.
-- Note: typos are in the ENGLISH name; filter on product_category_name_english.

UPDATE clean.category_translation
SET product_category_name_english = 'fashion_female_clothing',
    display_name                  = dbo.TitleCase('fashion_female_clothing'),
    is_manual_override            = 1
WHERE product_category_name_english = 'fashio_female_clothing';

UPDATE clean.category_translation
SET product_category_name_english = 'construction_tools_garden',
    display_name                  = dbo.TitleCase('construction_tools_garden'),
    is_manual_override            = 1
WHERE product_category_name_english = 'costruction_tools_garden';

UPDATE clean.category_translation
SET product_category_name_english = 'construction_tools_tools',
    display_name                  = dbo.TitleCase('construction_tools_tools'),
    is_manual_override            = 1
WHERE product_category_name_english = 'costruction_tools_tools';

UPDATE clean.category_translation
SET product_category_name_english = 'home_comfort',
    display_name                  = dbo.TitleCase('home_comfort'),
    is_manual_override            = 1
WHERE product_category_name_english = 'home_confort';

UPDATE clean.category_translation
SET product_category_name_english = 'arts_and_craftsmanship',
    display_name                  = dbo.TitleCase('arts_and_craftsmanship'),
    is_manual_override            = 1
WHERE product_category_name_english = 'arts_and_craftmanship';

-- The 'unknown' bucket
INSERT INTO clean.category_translation
    (product_category_name, product_category_name_english, display_name, is_manual_override)
VALUES ('unknown', 'unknown', 'Unknown', 1);

DECLARE @cat_in  INT = (SELECT COUNT(*) FROM raw.category_translation);
DECLARE @cat_out INT = (SELECT COUNT(*) FROM clean.category_translation);
EXEC clean.usp_log_rule
    @rule_id          = 'CATEGORY_TRANSLATION',
    @rule_description = 'Load 71 base + 2 overrides + 1 unknown + 5 typo fixes + display_name',
    @table_name       = 'category_translation',
    @rows_in          = @cat_in,
    @rows_out         = @cat_out,
    @rows_flagged     = 0;
GO

PRINT 'clean.category_translation built.';
GO

-- -------------------------------------------------------------------------------
-- 4.2 clean.products
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.products', 'U') IS NOT NULL DROP TABLE clean.products;

CREATE TABLE clean.products (
    product_id                  NVARCHAR(50)  NOT NULL PRIMARY KEY,
    product_category_name       NVARCHAR(100) NOT NULL,
    category_name_english       NVARCHAR(100) NOT NULL,
    category_display_name       NVARCHAR(100) NOT NULL,
    product_name_length         INT           NULL,
    product_description_length  INT           NULL,
    product_photos_qty          INT           NULL,
    product_weight_g            INT           NULL,
    product_length_cm           INT           NULL,
    product_height_cm           INT           NULL,
    product_width_cm            INT           NULL,
    flag_missing_dimensions     BIT           NOT NULL DEFAULT 0
);

INSERT INTO clean.products
    (product_id, product_category_name,
     category_name_english, category_display_name,
     product_name_length, product_description_length, product_photos_qty,
     product_weight_g, product_length_cm, product_height_cm, product_width_cm,
     flag_missing_dimensions)
SELECT
    p.product_id,
    COALESCE(LOWER(LTRIM(RTRIM(p.product_category_name))), 'unknown'),
    COALESCE(t.product_category_name_english, 'unknown'),
    COALESCE(t.display_name, 'Unknown'),
    TRY_CONVERT(INT, p.product_name_lenght),
    TRY_CONVERT(INT, p.product_description_lenght),
    TRY_CONVERT(INT, p.product_photos_qty),
    TRY_CONVERT(INT, p.product_weight_g),
    TRY_CONVERT(INT, p.product_length_cm),
    TRY_CONVERT(INT, p.product_height_cm),
    TRY_CONVERT(INT, p.product_width_cm),
    CASE
        WHEN p.product_weight_g    IS NULL
          OR p.product_length_cm   IS NULL
          OR p.product_height_cm   IS NULL
          OR p.product_width_cm    IS NULL
        THEN 1 ELSE 0
    END
FROM raw.products p
LEFT JOIN clean.category_translation t
    ON LOWER(LTRIM(RTRIM(p.product_category_name))) = t.product_category_name;

DECLARE @prod_in      INT = (SELECT COUNT(*) FROM raw.products);
DECLARE @prod_out     INT = (SELECT COUNT(*) FROM clean.products);
DECLARE @prod_flagged INT = (SELECT COUNT(*) FROM clean.products WHERE flag_missing_dimensions = 1);
EXEC clean.usp_log_rule
    @rule_id          = 'PRODUCTS_TYPED',
    @rule_description = 'Rename lenght -> length, resolve category, flag missing dimensions',
    @table_name       = 'products',
    @rows_in          = @prod_in,
    @rows_out         = @prod_out,
    @rows_flagged     = @prod_flagged;
GO

PRINT 'clean.products built.';
GO

-- -------------------------------------------------------------------------------
-- 4.3 clean.reviews
-- -------------------------------------------------------------------------------
IF OBJECT_ID('clean.reviews', 'U') IS NOT NULL DROP TABLE clean.reviews;

CREATE TABLE clean.reviews (
    order_id                 NVARCHAR(50)  NOT NULL PRIMARY KEY,
    review_id                NVARCHAR(50)  NOT NULL,
    review_score             INT           NOT NULL,
    review_comment_title     NVARCHAR(MAX) NULL,
    review_comment_message   NVARCHAR(MAX) NULL,
    review_creation_date     DATETIME2     NULL,
    review_answer_timestamp  DATETIME2     NULL
);

;WITH ranked AS (
    SELECT
        order_id,
        review_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY
                TRY_CONVERT(DATETIME2, review_creation_date)     DESC,
                TRY_CONVERT(DATETIME2, review_answer_timestamp)  DESC,
                review_id                                        ASC
        ) AS rn
    FROM raw.reviews
)
INSERT INTO clean.reviews
    (order_id, review_id, review_score,
     review_comment_title, review_comment_message,
     review_creation_date, review_answer_timestamp)
SELECT
    order_id,
    review_id,
    TRY_CONVERT(INT, review_score),
    review_comment_title,
    review_comment_message,
    TRY_CONVERT(DATETIME2, review_creation_date),
    TRY_CONVERT(DATETIME2, review_answer_timestamp)
FROM ranked
WHERE rn = 1;

DECLARE @rev_in   INT = (SELECT COUNT(*) FROM raw.reviews);
DECLARE @rev_out  INT = (SELECT COUNT(*) FROM clean.reviews);
EXEC clean.usp_log_rule
    @rule_id          = 'REVIEWS_DEDUP',
    @rule_description = 'Dedup by order_id: latest creation, then answer, then review_id',
    @table_name       = 'reviews',
    @rows_in          = @rev_in,
    @rows_out         = @rev_out,
    @rows_flagged     = 0;
GO

PRINT 'clean.reviews built.';
GO

-- -------------------------------------------------------------------------------
-- 5. Verify
-- -------------------------------------------------------------------------------
SELECT 'clean.customers'   AS table_name, COUNT(*) AS rows FROM clean.customers
UNION ALL SELECT 'clean.sellers',      COUNT(*) FROM clean.sellers
UNION ALL SELECT 'clean.geolocation',  COUNT(*) FROM clean.geolocation
UNION ALL SELECT 'clean.orders',       COUNT(*) FROM clean.orders
UNION ALL SELECT 'clean.order_items',  COUNT(*) FROM clean.order_items
UNION ALL SELECT 'clean.payments',     COUNT(*) FROM clean.payments
UNION ALL SELECT 'clean.category_translation', COUNT(*) FROM clean.category_translation
UNION ALL SELECT 'clean.products',     COUNT(*) FROM clean.products
UNION ALL SELECT 'clean.reviews',      COUNT(*) FROM clean.reviews;
GO

-- Geolocation detail
SELECT
    COUNT(*) AS total_prefixes,
    SUM(CAST(is_coordinates_missing AS INT)) AS prefixes_missing_coords,
    SUM(filtered_count) AS coords_filtered
FROM clean.geolocation;
GO

-- Category typo corrections (filter on ENGLISH name)
SELECT product_category_name, product_category_name_english, display_name
FROM clean.category_translation
WHERE product_category_name_english IN (
    'fashion_female_clothing','construction_tools_garden','construction_tools_tools',
    'home_comfort','arts_and_craftsmanship'
)
ORDER BY product_category_name;
GO

-- Latest run's log
SELECT rule_id, table_name, rows_in, rows_out, rows_flagged
FROM clean.cleaning_log
WHERE run_id = (SELECT MAX(run_id) FROM clean.cleaning_log)
ORDER BY log_id;
GO