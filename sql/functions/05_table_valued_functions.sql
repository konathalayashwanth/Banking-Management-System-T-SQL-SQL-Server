-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: functions/05_table_valued_functions.sql
-- Description: 4 Table-Valued Functions (Inline + Multi-Statement)
-- ============================================================

USE BankingDB;
GO

-- ────────────────────────────────────────────────
-- TVF-001: fn_GetAccountStatement  [INLINE TVF]
-- Req: Date-range filtered transaction history
-- Called by: sp_GetAccountStatement
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_GetAccountStatement(
    @AccountID INT,
    @FromDate  DATE,
    @ToDate    DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        t.TransactionID,
        t.TransactionDate,
        t.TransactionType,
        t.Amount,
        t.BalanceAfter,
        t.Channel,
        t.Remarks,
        ISNULL(e.FirstName + ' ' + e.LastName, 'System') AS ProcessedBy
    FROM   Transactions t
    LEFT JOIN Employees e ON t.ProcessedBy = e.EmployeeID
    WHERE  t.AccountID = @AccountID
    AND    CAST(t.TransactionDate AS DATE) BETWEEN @FromDate AND @ToDate
);
GO

-- ────────────────────────────────────────────────
-- TVF-002: fn_GetCustomerPortfolio  [INLINE TVF]
-- Req: All active accounts for a customer
-- Called by: sp_CustomerFullReport
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_GetCustomerPortfolio(@CustomerID INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        a.AccountID,
        a.AccountNumber,
        at.TypeName                               AS AccountType,
        b.BranchName,
        a.Balance,
        a.AccountStatus,
        a.OpenedDate,
        at.InterestRate,
        dbo.fn_CheckMinBalance(a.AccountID)       AS MinBalanceStatus
    FROM   Accounts a
    JOIN   AccountTypes at ON a.AccountTypeID = at.AccountTypeID
    JOIN   Branches     b  ON a.BranchID = b.BranchID
    WHERE  a.CustomerID = @CustomerID
    AND    a.AccountStatus <> 'Closed'
);
GO

-- ────────────────────────────────────────────────
-- TVF-003: fn_GenerateLoanSchedule  [MULTI-STATEMENT TVF]
-- Req: Full EMI amortisation schedule per loan
-- Called by: Loan sanction letters, sp_CustomerFullReport
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_GenerateLoanSchedule(@LoanID INT)
RETURNS @Schedule TABLE (
    EMINumber          INT,
    DueDate            DATE,
    EMIAmount          DECIMAL(12,2),
    PrincipalPart      DECIMAL(12,2),
    InterestPart       DECIMAL(12,2),
    OutstandingBalance DECIMAL(15,2)
)
AS
BEGIN
    DECLARE @Principal   DECIMAL(15,2);
    DECLARE @AnnualRate  DECIMAL(5,2);
    DECLARE @Tenure      INT;
    DECLARE @EMI         DECIMAL(12,2);
    DECLARE @StartDate   DATE;
    DECLARE @MonthlyRate DECIMAL(10,6);

    SELECT
        @Principal  = PrincipalAmount,
        @AnnualRate = InterestRate,
        @Tenure     = TenureMonths,
        @EMI        = EMIAmount,
        @StartDate  = ISNULL(DisbursedDate, GETDATE())
    FROM Loans WHERE LoanID = @LoanID;

    IF @Principal IS NULL RETURN;

    SET @MonthlyRate = @AnnualRate / (12.0 * 100.0);

    DECLARE @i       INT           = 1;
    DECLARE @Balance DECIMAL(15,2) = @Principal;
    DECLARE @IntPart DECIMAL(12,2);
    DECLARE @PrinPart DECIMAL(12,2);

    WHILE @i <= @Tenure
    BEGIN
        SET @IntPart  = ROUND(@Balance * @MonthlyRate, 2);
        SET @PrinPart = @EMI - @IntPart;
        SET @Balance  = @Balance - @PrinPart;

        INSERT INTO @Schedule VALUES (
            @i,
            DATEADD(MONTH, @i, @StartDate),
            @EMI,
            @PrinPart,
            @IntPart,
            CASE WHEN @Balance < 0 THEN 0 ELSE @Balance END
        );
        SET @i = @i + 1;
    END;
    RETURN;
END;
GO

-- ────────────────────────────────────────────────
-- TVF-004: fn_GetOverdueLoans  [INLINE TVF]
-- Req: Collections / NPA detection feed
-- Called by: sp_BranchPerformanceReport, daily jobs
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_GetOverdueLoans(@DaysOverdue INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        l.LoanID,
        c.CustomerID,
        c.FirstName + ' ' + c.LastName           AS CustomerName,
        c.PhoneNumber,
        l.LoanType,
        l.PrincipalAmount,
        l.OutstandingAmount,
        lr.DueDate,
        DATEDIFF(DAY, lr.DueDate, GETDATE())      AS DaysOverdue,
        lr.EMIAmount                              AS OverdueEMI
    FROM   Loans l
    JOIN   Customers      c  ON l.CustomerID = c.CustomerID
    JOIN   LoanRepayments lr ON l.LoanID = lr.LoanID
    WHERE  lr.Status = 'Pending'
    AND    lr.DueDate < GETDATE()
    AND    DATEDIFF(DAY, lr.DueDate, GETDATE()) >= @DaysOverdue
);
GO

PRINT '✔ All 4 Table-Valued Functions created.';
GO
