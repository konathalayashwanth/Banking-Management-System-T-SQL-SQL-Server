-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: scripts/00_master_install.sql
-- Description: Run this single file to install the ENTIRE project.
--              Executes all scripts in the correct dependency order.
-- Usage: Open in SSMS → Execute (F5)
-- ============================================================

PRINT '================================================';
PRINT ' BANKING MANAGEMENT SYSTEM — FULL INSTALLATION';
PRINT ' Microsoft SQL Server 2019+';
PRINT '================================================';
PRINT '';

-- Step 1: Database
PRINT 'Step 1/8 — Creating database...';
:r sql/01_create_database.sql

-- Step 2: Tables
PRINT 'Step 2/8 — Creating tables...';
:r sql/tables/02_create_tables.sql

-- Step 3: Seed Data
PRINT 'Step 3/8 — Inserting seed data...';
:r sql/tables/03_seed_data.sql

-- Step 4: Scalar Functions
PRINT 'Step 4/8 — Creating scalar functions...';
:r sql/functions/04_scalar_functions.sql

-- Step 5: TVFs
PRINT 'Step 5/8 — Creating table-valued functions...';
:r sql/functions/05_table_valued_functions.sql

-- Step 6: Views
PRINT 'Step 6/8 — Creating views (including indexed/materialized)...';
:r sql/views/06_views.sql

-- Step 7: Triggers
PRINT 'Step 7/8 — Creating triggers...';
:r sql/triggers/07_triggers.sql

-- Step 8: Stored Procedures
PRINT 'Step 8/8 — Creating stored procedures (with cursors)...';
:r sql/stored_procedures/08_stored_procedures.sql

PRINT '';
PRINT '================================================';
PRINT ' INSTALLATION COMPLETE';
PRINT ' Run scripts/09_run_demo.sql to verify all objects';
PRINT '================================================';
GO
