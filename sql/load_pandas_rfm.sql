-- ===============================================================================
-- Script: load_pandas_rfm.sql
-- Purpose: Load the pandas per-customer RFM export into tests.pandas_rfm.
--          Requires the CSV at C:\data\olist\pandas_rfm.csv (or adjust path).
-- Re-runnable: drops and recreates tests.pandas_rfm.
-- ===============================================================================

:on error exit

USE OlistAnalytics;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'tests')
    EXEC('CREATE SCHEMA tests');
GO

IF OBJECT_ID('tests.pandas_rfm', 'U') IS NOT NULL
    DROP TABLE tests.pandas_rfm;
GO

CREATE TABLE tests.pandas_rfm (
    customer_unique_id  NVARCHAR(50)   NOT NULL PRIMARY KEY,
    recency_days        INT            NOT NULL,
    frequency           INT            NOT NULL,
    monetary            DECIMAL(18,2)  NOT NULL,
    r_score             INT            NOT NULL,
    f_band              NVARCHAR(2)    NOT NULL,
    m_score             INT            NOT NULL,
    segment             NVARCHAR(20)   NOT NULL
);
GO

BULK INSERT tests.pandas_rfm
FROM 'C:\data\olist\pandas_rfm.csv'
WITH (
    FORMAT          = 'CSV',
    FIRSTROW        = 2,
    FIELDQUOTE      = '"',
    CODEPAGE        = '65001',
    ROWTERMINATOR   = '0x0d0a',
    TABLOCK
);
GO

SELECT COUNT(*) AS loaded_rows FROM tests.pandas_rfm;
GO

PRINT 'tests.pandas_rfm loaded.';
GO