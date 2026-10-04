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