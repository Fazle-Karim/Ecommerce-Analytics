-- ===============================================================================
-- Script: 05_facts.sql
-- Purpose: Build the analytics fact tables.
--          Facts are restricted to the analytic population (97,905 orders).
--          Non-population orders are preserved in analytics.excluded_orders.
-- Run order: after 04_dimensions.sql.
--
-- IMPORTANT: fact_order_items carries is_late, review_score, order_status as
-- attributes for convenience. These MUST be aggregated at order grain:
--   DISTINCTCOUNT(order_id) or AVERAGEX(VALUES(order_id), ...)
--   NEVER with a plain AVG() — multi-item orders would be over-weighted.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

-- -------------------------------------------------------------------------------
-- 1. Ensure build log exists (idempotent — created by 04_dimensions.sql)
-- -------------------------------------------------------------------------------
IF OBJECT_ID('analytics.build_log', 'U') IS NULL
BEGIN
    RAISERROR('analytics.build_log missing — run 04_dimensions.sql first.', 16, 1);
    RETURN;
END
GO

IF OBJECT_ID('tempdb..#analytics_run_ctx') IS NOT NULL DROP TABLE #analytics_run_ctx;
CREATE TABLE #analytics_run_ctx (run_id INT NOT NULL);
INSERT INTO #analytics_run_ctx (run_id)
SELECT ISNULL(MAX(run_id), 0) + 1 FROM analytics.build_log;

DECLARE @run_id INT = (SELECT run_id FROM #analytics_run_ctx);
PRINT 'Facts layer run_id = ' + CAST(@run_id AS NVARCHAR(10));
GO

-- ===============================================================================
-- SECTION 1: excluded_orders
-- ===============================================================================

IF OBJECT_ID('analytics.excluded_orders', 'U') IS NOT NULL DROP TABLE analytics.excluded_orders;

CREATE TABLE analytics.excluded_orders (
    order_id             NVARCHAR(50)  NOT NULL PRIMARY KEY,
    order_status         NVARCHAR(50)  NOT NULL,
    order_purchase_timestamp DATETIME2 NULL,
    exclusion_reason     NVARCHAR(50)  NOT NULL
);

INSERT INTO analytics.excluded_orders
    (order_id, order_status, order_purchase_timestamp, exclusion_reason)
SELECT
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    CASE
        WHEN o.order_status NOT IN ('delivered','shipped','invoiced','processing','approved')
            THEN 'out_of_scope_status'
        WHEN o.order_purchase_timestamp < '2017-01-01'
          OR o.order_purchase_timestamp >= '2018-09-01'
            THEN 'out_of_window'
        ELSE 'unclassified'
    END
FROM clean.orders o
WHERE NOT (
    o.order_status IN ('delivered','shipped','invoiced','processing','approved')
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp <  '2018-09-01'
);

DECLARE @excl_count INT = (SELECT COUNT(*) FROM analytics.excluded_orders);
EXEC analytics.usp_log_build
    @step_id          = 'EXCLUDED_ORDERS_BUILD',
    @step_description = 'Orders not in analytic population, tagged with exclusion reason',
    @object_name      = 'analytics.excluded_orders',
    @rows_written     = @excl_count;
GO

PRINT 'analytics.excluded_orders built.';
GO

-- ===============================================================================
-- SECTION 2: fact_orders
-- ===============================================================================

IF OBJECT_ID('analytics.fact_orders', 'U') IS NOT NULL DROP TABLE analytics.fact_orders;

CREATE TABLE analytics.fact_orders (
    order_key                      INT IDENTITY(1,1) PRIMARY KEY,
    order_id                       NVARCHAR(50)   NOT NULL,   -- natural key
    customer_key                   INT            NOT NULL,   -- FK -> dim_customer
    date_key                       INT            NOT NULL,   -- FK -> dim_date (purchase date)
    customer_id                    NVARCHAR(50)   NOT NULL,
    customer_unique_id             NVARCHAR(50)   NOT NULL,
    order_status                   NVARCHAR(50)   NOT NULL,
    order_purchase_timestamp       DATETIME2      NULL,
    order_approved_at              DATETIME2      NULL,
    order_delivered_carrier_date   DATETIME2      NULL,
    order_delivered_customer_date  DATETIME2      NULL,
    order_estimated_delivery_date  DATETIME2      NULL,
    delivery_days                  INT            NULL,
    is_late                        BIT            NOT NULL DEFAULT 0,
    review_score                   INT            NULL,
    payment_total                  DECIMAL(18,2)  NULL,
    item_count                     INT            NOT NULL DEFAULT 0,
    seller_count                   INT            NOT NULL DEFAULT 0
);

;WITH population AS (
    SELECT
        o.order_id,
        o.customer_id,
        o.order_status,
        o.order_purchase_timestamp,
        o.order_approved_at,
        o.order_delivered_carrier_date,
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM clean.orders o
    WHERE o.order_status IN ('delivered','shipped','invoiced','processing','approved')
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp <  '2018-09-01'
),
cust_resolved AS (
    SELECT
        p.*,
        c.customer_unique_id,
        dc.customer_key
    FROM population p
    JOIN clean.customers c ON c.customer_id = p.customer_id
    JOIN analytics.dim_customer dc ON dc.customer_unique_id = c.customer_unique_id
),
items_agg AS (
    SELECT order_id, COUNT(*) AS item_count, COUNT(DISTINCT seller_id) AS seller_count
    FROM clean.order_items
    GROUP BY order_id
),
pay_agg AS (
    SELECT order_id, SUM(payment_value) AS payment_total
    FROM clean.payments
    GROUP BY order_id
)
INSERT INTO analytics.fact_orders
    (order_id, customer_key, date_key,
     customer_id, customer_unique_id,
     order_status, order_purchase_timestamp, order_approved_at,
     order_delivered_carrier_date, order_delivered_customer_date,
     order_estimated_delivery_date,
     delivery_days, is_late, review_score, payment_total,
     item_count, seller_count)
SELECT
    cr.order_id,
    cr.customer_key,
    CAST(CONVERT(NVARCHAR(8), cr.order_purchase_timestamp, 112) AS INT) AS date_key,
    cr.customer_id,
    cr.customer_unique_id,
    cr.order_status,
    cr.order_purchase_timestamp,
    cr.order_approved_at,
    cr.order_delivered_carrier_date,
    cr.order_delivered_customer_date,
    cr.order_estimated_delivery_date,
    CASE
        WHEN cr.order_delivered_customer_date IS NOT NULL
        THEN DATEDIFF(DAY, cr.order_purchase_timestamp, cr.order_delivered_customer_date)
        ELSE NULL
    END AS delivery_days,
    CASE
        WHEN cr.order_status = 'delivered'
         AND cr.order_delivered_customer_date IS NOT NULL
         AND CAST(cr.order_delivered_customer_date AS DATE) >
             CAST(cr.order_estimated_delivery_date AS DATE)
        THEN 1 ELSE 0
    END AS is_late,
    r.review_score,
    p.payment_total,
    ISNULL(i.item_count, 0),
    ISNULL(i.seller_count, 0)
FROM cust_resolved cr
LEFT JOIN clean.reviews r ON r.order_id = cr.order_id
LEFT JOIN pay_agg p        ON p.order_id = cr.order_id
LEFT JOIN items_agg i      ON i.order_id = cr.order_id;

DECLARE @fo_count INT = (SELECT COUNT(*) FROM analytics.fact_orders);
EXEC analytics.usp_log_build
    @step_id          = 'FACT_ORDERS_BUILD',
    @step_description = 'One row per analytic order; delivery days, is_late, review, payment aggregated',
    @object_name      = 'analytics.fact_orders',
    @rows_written     = @fo_count;
GO

PRINT 'analytics.fact_orders built.';
GO

-- ===============================================================================
-- SECTION 3: fact_order_items
-- ===============================================================================

IF OBJECT_ID('analytics.fact_order_items', 'U') IS NOT NULL DROP TABLE analytics.fact_order_items;

CREATE TABLE analytics.fact_order_items (
    order_item_key             INT IDENTITY(1,1) PRIMARY KEY,
    order_id                   NVARCHAR(50)   NOT NULL,
    order_item_id              INT            NOT NULL,
    order_key                  INT            NOT NULL,   -- FK -> fact_orders
    product_key                INT            NOT NULL,   -- FK -> dim_product
    seller_key                 INT            NOT NULL,   -- FK -> dim_seller
    customer_key               INT            NOT NULL,   -- FK -> dim_customer
    date_key                   INT            NOT NULL,   -- FK -> dim_date
    product_id                 NVARCHAR(50)   NOT NULL,
    seller_id                  NVARCHAR(50)   NOT NULL,
    shipping_limit_date        DATETIME2      NULL,
    price                      DECIMAL(18,2)  NULL,
    freight_value              DECIMAL(18,2)  NULL,
    flag_shipping_limit_anomaly BIT           NOT NULL DEFAULT 0,
    -- Attributes copied from order grain. Aggregate at order grain only.
    is_late                    BIT            NOT NULL DEFAULT 0,
    review_score               INT            NULL,
    order_status               NVARCHAR(50)   NOT NULL
);

INSERT INTO analytics.fact_order_items
    (order_id, order_item_id, order_key, product_key, seller_key,
     customer_key, date_key, product_id, seller_id,
     shipping_limit_date, price, freight_value,
     flag_shipping_limit_anomaly,
     is_late, review_score, order_status)
SELECT
    oi.order_id,
    oi.order_item_id,
    fo.order_key,
    dp.product_key,
    ds.seller_key,
    fo.customer_key,
    fo.date_key,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,
    oi.flag_shipping_limit_anomaly,
    fo.is_late,
    fo.review_score,
    fo.order_status
FROM clean.order_items oi
JOIN analytics.fact_orders   fo ON fo.order_id   = oi.order_id
JOIN analytics.dim_product   dp ON dp.product_id = oi.product_id
JOIN analytics.dim_seller    ds ON ds.seller_id  = oi.seller_id;

DECLARE @fi_count INT = (SELECT COUNT(*) FROM analytics.fact_order_items);
EXEC analytics.usp_log_build
    @step_id          = 'FACT_ORDER_ITEMS_BUILD',
    @step_description = 'One row per analytic order item with denormalized order-level attributes',
    @object_name      = 'analytics.fact_order_items',
    @rows_written     = @fi_count;
GO

PRINT 'analytics.fact_order_items built.';
GO

-- ===============================================================================
-- SECTION 4: Verify
-- ===============================================================================

SELECT 'analytics.excluded_orders'   AS table_name, COUNT(*) AS rows FROM analytics.excluded_orders
UNION ALL SELECT 'analytics.fact_orders',       COUNT(*) FROM analytics.fact_orders
UNION ALL SELECT 'analytics.fact_order_items',  COUNT(*) FROM analytics.fact_order_items;
GO

-- identity: fact_orders + excluded_orders = 99,441
SELECT
    (SELECT COUNT(*) FROM analytics.fact_orders)      AS fact_orders,
    (SELECT COUNT(*) FROM analytics.excluded_orders)  AS excluded_orders,
    (SELECT COUNT(*) FROM analytics.fact_orders)
      + (SELECT COUNT(*) FROM analytics.excluded_orders) AS total
;
GO

-- exclusion reason breakdown
SELECT exclusion_reason, COUNT(*) AS n
FROM analytics.excluded_orders
GROUP BY exclusion_reason
ORDER BY exclusion_reason;
GO

-- fact_orders: late rate on delivered orders with a delivery date
SELECT
    COUNT(*)                                                       AS total_orders,
    SUM(CASE WHEN order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END)
                                                                   AS delivered_with_date,
    SUM(CAST(is_late AS INT))                                      AS late_orders,
    CAST(100.0 * SUM(CAST(is_late AS INT))
         / NULLIF(SUM(CASE WHEN order_status = 'delivered'
              AND order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END), 0)
    AS DECIMAL(5,2))                                               AS late_rate_pct
FROM analytics.fact_orders;
GO

-- Latest build log
SELECT step_id, object_name, rows_written
FROM analytics.build_log
WHERE run_id = (SELECT MAX(run_id) FROM analytics.build_log)
ORDER BY log_id;
GO