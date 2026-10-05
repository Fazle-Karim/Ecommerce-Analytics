-- ===============================================================================
-- Script: 07_bi_views.sql
-- Purpose: Create the bi schema with slim views for Power BI.
--          Power BI imports ONLY these views, never the analytics tables.
--
-- Design rules:
--   * Drop all NVARCHAR natural keys (order_id, customer_id, product_id,
--     seller_id, customer_unique_id) so the model joins only on integer keys.
--   * Drop all DATETIME2 timestamps from fact_orders — the date_key already
--     carries the calendar date. delivery_days is stored as an INT measure.
--   * Keep flags (is_late, is_first_order, flag_*) and measures.
--   * Keep date_key columns for relationships to dim_date.
--
-- Run order: after 06_rfm_cohorts.sql.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bi')
    EXEC('CREATE SCHEMA bi');
GO

-- -------------------------------------------------------------------------------
-- bi.dim_date
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.dim_date', 'V') IS NOT NULL DROP VIEW bi.dim_date;
GO

CREATE VIEW bi.dim_date AS
SELECT
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    year_month_key,
    month_label,
    month_start_date,
    week_of_year,
    day_of_week,
    day_name,
    is_in_window,
    is_jan_aug
FROM analytics.dim_date;
GO

-- -------------------------------------------------------------------------------
-- bi.dim_customer
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.dim_customer', 'V') IS NOT NULL DROP VIEW bi.dim_customer;
GO

CREATE VIEW bi.dim_customer AS
SELECT
    customer_key,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    geolocation_lat,
    geolocation_lng,
    coordinates_missing
FROM analytics.dim_customer;
GO

-- -------------------------------------------------------------------------------
-- bi.dim_product
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.dim_product', 'V') IS NOT NULL DROP VIEW bi.dim_product;
GO

CREATE VIEW bi.dim_product AS
SELECT
    product_key,
    product_category_name,
    category_name_english,
    category_display_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    flag_missing_dimensions
FROM analytics.dim_product;
GO

-- -------------------------------------------------------------------------------
-- bi.dim_seller
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.dim_seller', 'V') IS NOT NULL DROP VIEW bi.dim_seller;
GO

CREATE VIEW bi.dim_seller AS
SELECT
    seller_key,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    geolocation_lat,
    geolocation_lng,
    coordinates_missing
FROM analytics.dim_seller;
GO

-- -------------------------------------------------------------------------------
-- bi.fact_orders
--   One row per analytic order. Timestamps and natural keys removed.
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.fact_orders', 'V') IS NOT NULL DROP VIEW bi.fact_orders;
GO

CREATE VIEW bi.fact_orders AS
SELECT
    order_key,
    customer_key,
    date_key,
    order_status,
    delivery_days,
    is_late,
    review_score,
    payment_total,
    item_count,
    seller_count,
    customer_order_seq,
    is_first_order
FROM analytics.fact_orders;
GO

-- -------------------------------------------------------------------------------
-- bi.fact_order_items
--   One row per order item. Natural keys removed; carried order-level
--   attributes (is_late, review_score, order_status) kept for convenience.
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.fact_order_items', 'V') IS NOT NULL DROP VIEW bi.fact_order_items;
GO

CREATE VIEW bi.fact_order_items AS
SELECT
    order_item_key,
    order_key,
    product_key,
    seller_key,
    customer_key,
    date_key,
    shipping_limit_date,
    price,
    freight_value,
    flag_shipping_limit_anomaly,
    is_late,
    review_score,
    order_status
FROM analytics.fact_order_items;
GO

-- -------------------------------------------------------------------------------
-- bi.customer_rfm
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.customer_rfm', 'V') IS NOT NULL DROP VIEW bi.customer_rfm;
GO

CREATE VIEW bi.customer_rfm AS
SELECT
    customer_key,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_band,
    m_score,
    segment
FROM analytics.customer_rfm;
GO

-- -------------------------------------------------------------------------------
-- bi.cohort_retention
-- -------------------------------------------------------------------------------
IF OBJECT_ID('bi.cohort_retention', 'V') IS NOT NULL DROP VIEW bi.cohort_retention;
GO

CREATE VIEW bi.cohort_retention AS
SELECT
    cohort_month,
    cohort_month_start,
    month_offset,
    cohort_size,
    active_customers,
    retention_pct
FROM analytics.cohort_retention;
GO

-- ===============================================================================
-- Verify
-- ===============================================================================

SELECT 'bi.dim_date'          AS view_name, COUNT(*) AS rows FROM bi.dim_date
UNION ALL SELECT 'bi.dim_customer',       COUNT(*) FROM bi.dim_customer
UNION ALL SELECT 'bi.dim_product',        COUNT(*) FROM bi.dim_product
UNION ALL SELECT 'bi.dim_seller',         COUNT(*) FROM bi.dim_seller
UNION ALL SELECT 'bi.fact_orders',        COUNT(*) FROM bi.fact_orders
UNION ALL SELECT 'bi.fact_order_items',   COUNT(*) FROM bi.fact_order_items
UNION ALL SELECT 'bi.customer_rfm',       COUNT(*) FROM bi.customer_rfm
UNION ALL SELECT 'bi.cohort_retention',   COUNT(*) FROM bi.cohort_retention;
GO

-- Column check: confirm no timestamps and no natural-key text columns
-- in bi.fact_orders. order_status is allowed (categorical attribute).
SELECT
    CASE WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'bi' AND TABLE_NAME = 'fact_orders'
          AND DATA_TYPE IN ('datetime2','datetime','date','time')
    ) THEN 'FAIL: datetime column present in bi.fact_orders'
    WHEN EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = 'bi' AND TABLE_NAME = 'fact_orders'
          AND DATA_TYPE IN ('nvarchar','varchar')
          AND COLUMN_NAME NOT IN ('order_status')
    ) THEN 'FAIL: unexpected text column in bi.fact_orders'
    ELSE 'PASS: bi.fact_orders is slim (no timestamps, no natural keys)'
    END AS check_result;
GO