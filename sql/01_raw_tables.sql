-- ===============================================================================
-- Script: 01_raw_tables.sql
-- Description: Database, Schema Creation, and Staging Tables (raw layer)
-- Notes: Idempotent — safe to re-run. Uses IF NOT EXISTS guards throughout.
-- ===============================================================================

-- 1. Create Database (if not exists)
IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'OlistAnalytics')
BEGIN
    CREATE DATABASE OlistAnalytics;
END
GO

USE OlistAnalytics;
GO

-- 2. Create Schemas (if not exists)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'raw')
    EXEC('CREATE SCHEMA raw');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'clean')
    EXEC('CREATE SCHEMA clean');
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO

-- 3. Drop existing raw tables if they exist (allows clean re-run)
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

-- 4. Create Raw Staging Tables (NVARCHAR to prevent bulk insert errors)
CREATE TABLE raw.orders (
    order_id                        NVARCHAR(50),
    customer_id                     NVARCHAR(50),
    order_status                    NVARCHAR(50),
    order_purchase_timestamp        NVARCHAR(50),
    order_approved_at               NVARCHAR(50),
    order_delivered_carrier_date    NVARCHAR(50),
    order_delivered_customer_date   NVARCHAR(50),
    order_estimated_delivery_date   NVARCHAR(50)
);

CREATE TABLE raw.order_items (
    order_id            NVARCHAR(50),
    order_item_id       NVARCHAR(50),
    product_id          NVARCHAR(50),
    seller_id           NVARCHAR(50),
    shipping_limit_date NVARCHAR(50),
    price               NVARCHAR(50),
    freight_value       NVARCHAR(50)
);

CREATE TABLE raw.payments (
    order_id                NVARCHAR(50),
    payment_sequential      NVARCHAR(50),
    payment_type            NVARCHAR(50),
    payment_installments    NVARCHAR(50),
    payment_value           NVARCHAR(50)
);

CREATE TABLE raw.reviews (
    review_id                   NVARCHAR(50),
    order_id                    NVARCHAR(50),
    review_score                NVARCHAR(50),
    review_comment_title        NVARCHAR(MAX),
    review_comment_message      NVARCHAR(MAX),
    review_creation_date        NVARCHAR(50),
    review_answer_timestamp     NVARCHAR(50)
);

CREATE TABLE raw.customers (
    customer_id                 NVARCHAR(50),
    customer_unique_id          NVARCHAR(50),
    customer_zip_code_prefix    NVARCHAR(50),
    customer_city               NVARCHAR(100),
    customer_state              NVARCHAR(50)
);

CREATE TABLE raw.sellers (
    seller_id                   NVARCHAR(50),
    seller_zip_code_prefix      NVARCHAR(50),
    seller_city                 NVARCHAR(100),
    seller_state                NVARCHAR(50)
);

CREATE TABLE raw.products (
    product_id                  NVARCHAR(50),
    product_category_name       NVARCHAR(100),
    product_name_lenght         NVARCHAR(50),
    product_description_lenght  NVARCHAR(50),
    product_photos_qty          NVARCHAR(50),
    product_weight_g            NVARCHAR(50),
    product_length_cm           NVARCHAR(50),
    product_height_cm           NVARCHAR(50),
    product_width_cm            NVARCHAR(50)
);

CREATE TABLE raw.geolocation (
    geolocation_zip_code_prefix NVARCHAR(50),
    geolocation_lat             NVARCHAR(50),
    geolocation_lng             NVARCHAR(50),
    geolocation_city            NVARCHAR(100),
    geolocation_state           NVARCHAR(50)
);

CREATE TABLE raw.category_translation (
    product_category_name           NVARCHAR(100),
    product_category_name_english   NVARCHAR(100)
);
GO

PRINT 'Raw layer setup complete.';
GO