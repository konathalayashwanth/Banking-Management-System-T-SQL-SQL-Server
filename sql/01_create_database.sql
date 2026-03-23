-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: 01_create_database.sql
-- Description: Creates the BankingDB database
-- Author: Banking Dev Team
-- Platform: Microsoft SQL Server 2019+
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = 'BankingDB')
BEGIN
    ALTER DATABASE BankingDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE BankingDB;
    PRINT 'Existing BankingDB dropped.';
END;
GO

CREATE DATABASE BankingDB;
GO

USE BankingDB;
GO

PRINT '✔ BankingDB created successfully.';
GO
