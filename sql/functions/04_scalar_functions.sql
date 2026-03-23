-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: functions/04_scalar_functions.sql
-- Description: 5 Scalar Functions
-- ============================================================

USE BankingDB;
GO

-- ────────────────────────────────────────────────
-- SF-001: fn_CalculateAge
-- Business Rule BR-001: Customer must be >= 18 years old.
-- Called by: sp_CreateCustomer, vw_CustomerAccountSummary
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_CalculateAge(@DateOfBirth DATE)
RETURNS INT
AS
BEGIN
    DECLARE @Age INT;
    SET @Age = DATEDIFF(YEAR, @DateOfBirth, GETDATE())
             - CASE WHEN (MONTH(@DateOfBirth) > MONTH(GETDATE()))
                      OR (MONTH(@DateOfBirth) = MONTH(GETDATE())
                          AND DAY(@DateOfBirth) > DAY(GETDATE()))
                    THEN 1 ELSE 0 END;
    RETURN @Age;
END;
GO

-- ────────────────────────────────────────────────
-- SF-002: fn_CalculateEMI
-- Business Rule BR-010: EMI = P * r * (1+r)^n / ((1+r)^n - 1)
-- Called by: sp_ApplyLoan
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_CalculateEMI(
    @Principal    DECIMAL(15,2),
    @AnnualRate   DECIMAL(5,2),
    @TenureMonths INT
)
RETURNS DECIMAL(12,2)
AS
BEGIN
    IF @AnnualRate = 0
        RETURN @Principal / @TenureMonths;

    DECLARE @MonthlyRate DECIMAL(10,6);
    DECLARE @EMI         DECIMAL(12,2);

    SET @MonthlyRate = @AnnualRate / (12.0 * 100.0);
    SET @EMI = @Principal * @MonthlyRate
             * POWER(1 + @MonthlyRate, @TenureMonths)
             / (POWER(1 + @MonthlyRate, @TenureMonths) - 1);
    RETURN ROUND(@EMI, 2);
END;
GO

-- ────────────────────────────────────────────────
-- SF-003: fn_MaskAccountNumber
-- Business Rule BR-016: Show only last 4 digits (PCI-DSS)
-- Called by: sp_GetAccountStatement, sp_CustomerFullReport
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_MaskAccountNumber(@AccountNumber VARCHAR(20))
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN REPLICATE('X', LEN(@AccountNumber) - 4) + RIGHT(@AccountNumber, 4);
END;
GO

-- ────────────────────────────────────────────────
-- SF-004: fn_GetAccountBalance
-- Returns current balance for an account (read-only)
-- Called by: multiple SPs and reports
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_GetAccountBalance(@AccountID INT)
RETURNS DECIMAL(15,2)
AS
BEGIN
    DECLARE @Balance DECIMAL(15,2);
    SELECT @Balance = Balance FROM Accounts WHERE AccountID = @AccountID;
    RETURN ISNULL(@Balance, 0.00);
END;
GO

-- ────────────────────────────────────────────────
-- SF-005: fn_CheckMinBalance
-- Business Rule BR-005: Detect accounts below minimum balance
-- Called by: fn_GetCustomerPortfolio TVF
-- ────────────────────────────────────────────────
CREATE FUNCTION dbo.fn_CheckMinBalance(@AccountID INT)
RETURNS VARCHAR(10)
AS
BEGIN
    DECLARE @Balance    DECIMAL(15,2);
    DECLARE @MinBalance DECIMAL(15,2);

    SELECT @Balance = a.Balance, @MinBalance = at.MinBalance
    FROM   Accounts a
    JOIN   AccountTypes at ON a.AccountTypeID = at.AccountTypeID
    WHERE  a.AccountID = @AccountID;

    RETURN CASE WHEN @Balance >= @MinBalance THEN 'Compliant' ELSE 'Below Min' END;
END;
GO

PRINT '✔ All 5 scalar functions created.';
GO
