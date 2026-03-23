-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: scripts/09_run_demo.sql
-- Description: Full demo execution — test all objects
-- ============================================================

USE BankingDB;
GO

PRINT '=================================================';
PRINT ' BANKING MANAGEMENT SYSTEM — DEMO EXECUTION';
PRINT '=================================================';

-- ── 1. SCALAR FUNCTIONS ──────────────────────────────
PRINT ''; PRINT '--- Scalar Functions ---';

SELECT dbo.fn_CalculateAge('1990-05-15')        AS Age;
SELECT dbo.fn_CalculateEMI(500000, 12.00, 36)   AS EMI_Amount;
SELECT dbo.fn_MaskAccountNumber('ACC1000000001') AS MaskedAccount;
SELECT dbo.fn_GetAccountBalance(1)              AS CurrentBalance;
SELECT dbo.fn_CheckMinBalance(1)                AS MinBalanceStatus;
GO

-- ── 2. TABLE-VALUED FUNCTIONS ─────────────────────────
PRINT ''; PRINT '--- Table-Valued Functions ---';

SELECT * FROM dbo.fn_GetCustomerPortfolio(1);
SELECT * FROM dbo.fn_GetAccountStatement(1, '2020-01-01', '2026-12-31');
SELECT TOP 6 * FROM dbo.fn_GenerateLoanSchedule(1);
SELECT * FROM dbo.fn_GetOverdueLoans(0);
GO

-- ── 3. STANDARD VIEWS ────────────────────────────────
PRINT ''; PRINT '--- Views ---';

SELECT * FROM vw_CustomerAccountSummary;
SELECT * FROM vw_BranchPerformance;
SELECT * FROM vw_LoanPortfolio;
SELECT * FROM vw_DailyTransactionSummary;
GO

-- ── 4. INDEXED (MATERIALIZED) VIEWS ──────────────────
PRINT ''; PRINT '--- Materialized Views (NOEXPAND hint) ---';

SELECT * FROM vw_BranchBalanceSummary    WITH (NOEXPAND);
SELECT * FROM vw_MaterializedTxnSummary  WITH (NOEXPAND);
GO

-- ── 5. STORED PROCEDURES ─────────────────────────────
PRINT ''; PRINT '--- Stored Procedures ---';

-- Create a new customer
DECLARE @NewCust INT;
EXEC sp_CreateCustomer
    'Raju', 'Bhai', '1998-01-15', 'M',
    'raju.bhai@test.com', '9000000099',
    '5 Test Street', 'Hyderabad', 'Telangana', '500001',
    '999999999999', 'RAJBS9999Z', @NewCust OUTPUT;
PRINT 'New CustomerID = ' + CAST(@NewCust AS VARCHAR);
GO

-- Deposit
EXEC sp_Deposit    @AccountID=1, @Amount=15000, @Remarks='Salary credit',    @Channel='NetBanking';
-- Withdraw
EXEC sp_Withdraw   @AccountID=1, @Amount=5000,  @Remarks='ATM withdrawal',   @Channel='ATM';
-- Fund Transfer
EXEC sp_FundTransfer @FromAccountID=1, @ToAccountID=2, @Amount=10000, @Remarks='Rent payment';
GO

-- Apply a new loan
DECLARE @NewLoan INT;
EXEC sp_ApplyLoan
    @CustomerID=1, @BranchID=1, @LoanType='Personal',
    @PrincipalAmount=150000, @InterestRate=11.5, @TenureMonths=24,
    @NewLoanID=@NewLoan OUTPUT;
PRINT 'New LoanID = ' + CAST(@NewLoan AS VARCHAR);
GO

-- Account Statement
EXEC sp_GetAccountStatement @AccountID=1, @FromDate='2024-01-01', @ToDate='2026-12-31';
GO

-- Branch Performance Report (uses CURSOR)
EXEC sp_BranchPerformanceReport;
GO

-- Monthly Interest (uses CURSOR)
EXEC sp_ApplyMonthlyInterest;
GO

-- Mark Dormant (uses CURSOR)
EXEC sp_MarkDormantAccounts @InactiveDays=365;
GO

-- Customer Full Report (uses all object types)
EXEC sp_CustomerFullReport @CustomerID=1;
GO

-- ── 6. TRIGGER VERIFICATION ──────────────────────────
PRINT ''; PRINT '--- Audit Log (Trigger Output) ---';
SELECT TOP 20 * FROM AuditLog ORDER BY LogID DESC;
GO

PRINT '=================================================';
PRINT ' DEMO COMPLETE — ALL OBJECTS VERIFIED';
PRINT '=================================================';
GO
