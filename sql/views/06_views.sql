-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: views/06_views.sql
-- Description: 4 Standard Views + 2 Indexed (Materialized) Views
-- ============================================================

USE BankingDB;
GO

-- ────────────────────────────────────────────────
-- VW-001: vw_CustomerAccountSummary
-- Purpose: Customer 360 dashboard — total balance, account count, age
-- ────────────────────────────────────────────────
CREATE VIEW vw_CustomerAccountSummary
AS
    SELECT
        c.CustomerID,
        c.FirstName + ' ' + c.LastName      AS CustomerName,
        c.Email,
        c.PhoneNumber,
        c.KYCStatus,
        COUNT(a.AccountID)                  AS TotalAccounts,
        SUM(a.Balance)                      AS TotalBalance,
        MAX(a.Balance)                      AS HighestBalance,
        MIN(a.OpenedDate)                   AS OldestAccountDate,
        dbo.fn_CalculateAge(c.DateOfBirth)  AS Age
    FROM   Customers c
    LEFT JOIN Accounts a ON c.CustomerID = a.CustomerID
                         AND a.AccountStatus = 'Active'
    GROUP BY c.CustomerID, c.FirstName, c.LastName,
             c.Email, c.PhoneNumber, c.KYCStatus, c.DateOfBirth;
GO

-- ────────────────────────────────────────────────
-- VW-002: vw_BranchPerformance
-- Purpose: Monthly branch KPI — deposits, loans, staff
-- Called by: sp_BranchPerformanceReport
-- ────────────────────────────────────────────────
CREATE VIEW vw_BranchPerformance
AS
    SELECT
        b.BranchID,
        b.BranchName,
        b.City,
        COUNT(DISTINCT a.AccountID)         AS TotalAccounts,
        ISNULL(SUM(a.Balance), 0)           AS TotalDeposits,
        COUNT(DISTINCT l.LoanID)            AS TotalLoans,
        ISNULL(SUM(l.PrincipalAmount), 0)   AS TotalLoanAmount,
        ISNULL(SUM(l.OutstandingAmount), 0) AS TotalOutstanding,
        COUNT(DISTINCT e.EmployeeID)        AS TotalEmployees
    FROM   Branches b
    LEFT JOIN Accounts  a ON b.BranchID = a.BranchID AND a.AccountStatus = 'Active'
    LEFT JOIN Loans     l ON b.BranchID = l.BranchID AND l.LoanStatus = 'Disbursed'
    LEFT JOIN Employees e ON b.BranchID = e.BranchID AND e.IsActive = 1
    GROUP BY b.BranchID, b.BranchName, b.City;
GO

-- ────────────────────────────────────────────────
-- VW-003: vw_DailyTransactionSummary
-- Purpose: Daily MIS — channel-wise transaction volumes
-- ────────────────────────────────────────────────
CREATE VIEW vw_DailyTransactionSummary
AS
    SELECT
        CAST(t.TransactionDate AS DATE) AS TxnDate,
        t.TransactionType,
        t.Channel,
        COUNT(*)                        AS TotalTransactions,
        SUM(t.Amount)                   AS TotalAmount,
        AVG(t.Amount)                   AS AvgAmount,
        MAX(t.Amount)                   AS MaxAmount
    FROM   Transactions t
    GROUP BY CAST(t.TransactionDate AS DATE), t.TransactionType, t.Channel;
GO

-- ────────────────────────────────────────────────
-- VW-004: vw_LoanPortfolio
-- Purpose: Credit risk — active disbursed loan monitoring
-- ────────────────────────────────────────────────
CREATE VIEW vw_LoanPortfolio
AS
    SELECT
        l.LoanID,
        c.FirstName + ' ' + c.LastName                                    AS BorrowerName,
        c.PhoneNumber,
        l.LoanType,
        l.PrincipalAmount,
        l.InterestRate,
        l.TenureMonths,
        l.EMIAmount,
        l.DisbursedDate,
        l.OutstandingAmount,
        l.LoanStatus,
        b.BranchName,
        DATEDIFF(MONTH, l.DisbursedDate, GETDATE())                       AS MonthsElapsed,
        l.PrincipalAmount - ISNULL(l.OutstandingAmount, l.PrincipalAmount) AS PrincipalRepaid
    FROM   Loans l
    JOIN   Customers c ON l.CustomerID = c.CustomerID
    JOIN   Branches  b ON l.BranchID   = b.BranchID
    WHERE  l.LoanStatus IN ('Disbursed', 'NPA');
GO

-- ════════════════════════════════════════════════
-- INDEXED VIEWS (Materialized Views in SQL Server)
-- Requirement: WITH SCHEMABINDING + Unique Clustered Index
-- Query with: SELECT * FROM <view> WITH (NOEXPAND)
-- ════════════════════════════════════════════════

-- ────────────────────────────────────────────────
-- IVW-001: vw_BranchBalanceSummary  [INDEXED / MATERIALIZED]
-- Purpose: Pre-computed branch balance aggregates for real-time dashboard
-- ────────────────────────────────────────────────
CREATE VIEW vw_BranchBalanceSummary
WITH SCHEMABINDING
AS
    SELECT
        a.BranchID,
        COUNT_BIG(*)           AS TotalAccountCount,
        SUM(a.Balance)         AS TotalBalance,
        COUNT_BIG(a.AccountID) AS ActiveAccountCount
    FROM   dbo.Accounts a
    WHERE  a.AccountStatus = 'Active'
    GROUP BY a.BranchID;
GO

CREATE UNIQUE CLUSTERED INDEX IX_BranchBalanceSummary
    ON vw_BranchBalanceSummary(BranchID);
GO

-- ────────────────────────────────────────────────
-- IVW-002: vw_MaterializedTxnSummary  [INDEXED / MATERIALIZED]
-- Purpose: Per-account transaction totals for fraud detection
-- ────────────────────────────────────────────────
CREATE VIEW vw_MaterializedTxnSummary
WITH SCHEMABINDING
AS
    SELECT
        t.AccountID,
        COUNT_BIG(*) AS TxnCount,
        SUM(t.Amount) AS TotalAmount
    FROM   dbo.Transactions t
    GROUP BY t.AccountID;
GO

CREATE UNIQUE CLUSTERED INDEX IX_MaterializedTxnSummary
    ON vw_MaterializedTxnSummary(AccountID);
GO

PRINT '✔ All 6 Views created (4 standard + 2 indexed/materialized).';
GO
