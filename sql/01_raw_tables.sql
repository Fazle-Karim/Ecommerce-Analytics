-- ===============================================================================
-- Script: 01_raw_tables.sql
-- Purpose: Create the database, three schemas, and nine raw staging tables.
--          Uses VARCHAR for text columns so UTF-8 bytes are preserved exactly.
--          Type casting to NVARCHAR / DATE / DECIMAL happens in Step 4 (cleaning).
-- ===============================================================================

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'OlistAnalytics')
BEGIN
    CREATE DATABASE OlistAnalytics;
END
GO

USE OlistAnalytics;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
    EXEC('CREATE SCHEMA raw');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'clean')
    EXEC('CREATE SCHEMA clean');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO

IF OBJECT_ID('raw.orders', 'U')               IS NOT NULL DROP TABLE raw.orders;
IF OBJECT_ID('raw.order_items', 'U')          IS NOT NULL DROP TABLE raw.order_items;
IF OBJECT_ID('raw.payments', 'U')             IS NOT NULL DROP TABLE raw.payments;
IF OBJECT_ID('raw.reviews', 'U')              IS NOT NULL DROP TABLE raw.reviews;
IF OBJECT_ID('raw.customers', 'U')            IS NOT NULL DROP TABLE raw.customers;
IF OBJECT_ID('raw.sellers', 'U')              IS NOT NULL DROP TABLE raw.sellers;
IF OBJECT_ID('raw.products', 'U')             IS NOT NULL DROP TABLE raw.products;
IF OBJECT_ID('raw.geolocation', 'U')          IS NOT NULL DROP TABLE raw.geolocation;
IF OBJECT_ID('raw.category_translation', 'U') IS NOT NULL DROP TABLE raw.category_translation;
GO

CREATE TABLE raw.orders (
    order_id                        VARCHAR(50),
    customer_id                     VARCHAR(50),
    order_status                    VARCHAR(50),
    order_purchase_timestamp        VARCHAR(50),
    order_approved_at               VARCHAR(50),
    order_delivered_carrier_date    VARCHAR(50),
    order_delivered_customer_date   VARCHAR(50),
    order_estimated_delivery_date   VARCHAR(50)
);

CREATE TABLE raw.order_items (
    order_id            VARCHAR(50),
    order_item_id       VARCHAR(50),
    product_id          VARCHAR(50),
    seller_id           VARCHAR(50),
    shipping_limit_date VARCHAR(50),
    price               VARCHAR(50),
    freight_value       VARCHAR(50)
);

CREATE TABLE raw.payments (
    order_id                VARCHAR(50),
    payment_sequential      VARCHAR(50),
    payment_type            VARCHAR(50),
    payment_installments    VARCHAR(50),
    payment_value           VARCHAR(50)
);

CREATE TABLE raw.reviews (
    review_id                   VARCHAR(50),
    order_id                    VARCHAR(50),
    review_score                VARCHAR(50),
    review_comment_title        VARCHAR(MAX),
    review_comment_message      VARCHAR(MAX),
    review_creation_date        VARCHAR(50),
    review_answer_timestamp     VARCHAR(50)
);

CREATE TABLE raw.customers (
    customer_id                 VARCHAR(50),
    customer_unique_id          VARCHAR(50),
    customer_zip_code_prefix    VARCHAR(50),
    customer_city               VARCHAR(100),
    customer_state              VARCHAR(50)
);

CREATE TABLE raw.sellers (
    seller_id                   VARCHAR(50),
    seller_zip_code_prefix      VARCHAR(50),
    seller_city                 VARCHAR(100),
    seller_state                VARCHAR(50)
);

CREATE TABLE raw.products (
    product_id                  VARCHAR(50),
    product_category_name       VARCHAR(100),
    product_name_lenght         VARCHAR(50),
    product_description_lenght  VARCHAR(50),
    product_photos_qty          VARCHAR(50),
    product_weight_g            VARCHAR(50),
    product_length_cm           VARCHAR(50),
    product_height_cm           VARCHAR(50),
    product_width_cm            VARCHAR(50)
);

CREATE TABLE raw.geolocation (
    geolocation_zip_code_prefix VARCHAR(50),
    geolocation_lat             VARCHAR(50),
    geolocation_lng             VARCHAR(50),
    geolocation_city            VARCHAR(100),
    geolocation_state           VARCHAR(50)
);

CREATE TABLE raw.category_translation (
    product_category_name           VARCHAR(100),
    product_category_name_english   VARCHAR(100)
);
GO

PRINT 'Raw layer setup complete.';
GO