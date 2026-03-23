-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: stored_procedures/08_stored_procedures.sql
-- Description: 12 Stored Procedures (enclosing all objects + 3 Cursors)
-- ============================================================

USE BankingDB;
GO

-- ════════════════════════════════════════════════
-- SP-001: sp_CreateCustomer
-- Req: Register a new customer. Validate age >= 18 via fn_CalculateAge.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_CreateCustomer
    @FirstName     VARCHAR(50),
    @LastName      VARCHAR(50),
    @DateOfBirth   DATE,
    @Gender        CHAR(1),
    @Email         VARCHAR(100),
    @PhoneNumber   VARCHAR(15),
    @Address       VARCHAR(200),
    @City          VARCHAR(50),
    @State         VARCHAR(50),
    @PINCode       VARCHAR(10),
    @AadhaarNumber VARCHAR(12) = NULL,
    @PANNumber     VARCHAR(10) = NULL,
    @NewCustomerID INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF dbo.fn_CalculateAge(@DateOfBirth) < 18
        BEGIN
            RAISERROR('Customer must be at least 18 years old.', 16, 1);
            ROLLBACK; RETURN;
        END;

        IF EXISTS (SELECT 1 FROM Customers WHERE Email = @Email)
        BEGIN
            RAISERROR('Email [%s] is already registered.', 16, 1, @Email);
            ROLLBACK; RETURN;
        END;

        INSERT INTO Customers (FirstName, LastName, DateOfBirth, Gender, Email, PhoneNumber,
                               Address, City, State, PINCode, AadhaarNumber, PANNumber)
        VALUES (@FirstName, @LastName, @DateOfBirth, @Gender, @Email, @PhoneNumber,
                @Address, @City, @State, @PINCode, @AadhaarNumber, @PANNumber);

        SET @NewCustomerID = SCOPE_IDENTITY();
        COMMIT;
        PRINT 'Customer created. ID: ' + CAST(@NewCustomerID AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-002: sp_OpenAccount
-- Req: Open account for KYC-verified customer; initial deposit >= MinBalance.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_OpenAccount
    @CustomerID     INT,
    @BranchID       INT,
    @AccountTypeID  INT,
    @InitialDeposit DECIMAL(15,2),
    @NewAccountID   INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Customers
                       WHERE CustomerID = @CustomerID AND IsActive = 1 AND KYCStatus = 'Verified')
        BEGIN
            RAISERROR('Customer is inactive or KYC not verified.', 16, 1);
            ROLLBACK; RETURN;
        END;

        DECLARE @MinBal DECIMAL(15,2);
        SELECT @MinBal = MinBalance FROM AccountTypes WHERE AccountTypeID = @AccountTypeID;

        IF @InitialDeposit < @MinBal
        BEGIN
            RAISERROR('Initial deposit %.2f is below minimum balance %.2f.', 16, 1,
                       @InitialDeposit, @MinBal);
            ROLLBACK; RETURN;
        END;

        DECLARE @AccNum VARCHAR(20);
        SET @AccNum = 'ACC' + FORMAT(GETDATE(),'yyyyMMdd')
                    + RIGHT('0000' + CAST((SELECT ISNULL(MAX(AccountID),0)+1 FROM Accounts) AS VARCHAR), 4);

        INSERT INTO Accounts (AccountNumber, CustomerID, BranchID, AccountTypeID, Balance, IFSC)
        SELECT @AccNum, @CustomerID, @BranchID, @AccountTypeID, @InitialDeposit,
               'BANK0' + BranchCode
        FROM   Branches WHERE BranchID = @BranchID;

        SET @NewAccountID = SCOPE_IDENTITY();

        INSERT INTO Transactions (AccountID, TransactionType, Amount, BalanceAfter, Remarks, Channel)
        VALUES (@NewAccountID, 'Deposit', @InitialDeposit, @InitialDeposit,
                'Account opening deposit', 'Branch');

        COMMIT;
        PRINT 'Account opened: ' + @AccNum;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-003: sp_Deposit
-- Req: Process cash / electronic deposit. Never update Balance directly.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_Deposit
    @AccountID  INT,
    @Amount     DECIMAL(15,2),
    @Remarks    VARCHAR(200) = NULL,
    @Channel    VARCHAR(20)  = 'Branch',
    @EmployeeID INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Amount <= 0
        BEGIN RAISERROR('Deposit amount must be positive.', 16, 1); ROLLBACK; RETURN; END;

        IF NOT EXISTS (SELECT 1 FROM Accounts WHERE AccountID = @AccountID AND AccountStatus = 'Active')
        BEGIN RAISERROR('Account %d not found or not active.', 16, 1, @AccountID); ROLLBACK; RETURN; END;

        DECLARE @NewBalance DECIMAL(15,2);
        SELECT @NewBalance = Balance + @Amount FROM Accounts WHERE AccountID = @AccountID;

        INSERT INTO Transactions (AccountID, TransactionType, Amount, BalanceAfter, Remarks, ProcessedBy, Channel)
        VALUES (@AccountID, 'Deposit', @Amount, @NewBalance, @Remarks, @EmployeeID, @Channel);

        COMMIT;
        PRINT 'Deposit successful. New balance: ' + CAST(@NewBalance AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-004: sp_Withdraw
-- Req: Withdrawal with minimum balance enforcement (BR-005).
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_Withdraw
    @AccountID  INT,
    @Amount     DECIMAL(15,2),
    @Remarks    VARCHAR(200) = NULL,
    @Channel    VARCHAR(20)  = 'ATM',
    @EmployeeID INT          = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Balance    DECIMAL(15,2);
        DECLARE @MinBalance DECIMAL(15,2);

        SELECT @Balance = a.Balance, @MinBalance = at.MinBalance
        FROM   Accounts a
        JOIN   AccountTypes at ON a.AccountTypeID = at.AccountTypeID
        WHERE  a.AccountID = @AccountID AND a.AccountStatus = 'Active';

        IF @Balance IS NULL
        BEGIN RAISERROR('Account %d not found or not active.', 16, 1, @AccountID); ROLLBACK; RETURN; END;

        IF @Amount <= 0
        BEGIN RAISERROR('Withdrawal amount must be positive.', 16, 1); ROLLBACK; RETURN; END;

        IF (@Balance - @Amount) < @MinBalance
        BEGIN
            RAISERROR('Insufficient balance. Available: %.2f  |  Min Required: %.2f', 16, 1,
                       @Balance, @MinBalance);
            ROLLBACK; RETURN;
        END;

        INSERT INTO Transactions (AccountID, TransactionType, Amount, BalanceAfter, Remarks, ProcessedBy, Channel)
        VALUES (@AccountID, 'Withdrawal', @Amount, @Balance - @Amount, @Remarks, @EmployeeID, @Channel);

        COMMIT;
        PRINT 'Withdrawal successful. New balance: ' + CAST((@Balance - @Amount) AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-005: sp_FundTransfer
-- Req: Atomic two-legged transfer. BR-007 — both legs succeed or both roll back.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_FundTransfer
    @FromAccountID INT,
    @ToAccountID   INT,
    @Amount        DECIMAL(15,2),
    @Remarks       VARCHAR(200) = 'Fund Transfer',
    @Channel       VARCHAR(20)  = 'NetBanking'
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF @FromAccountID = @ToAccountID
        BEGIN RAISERROR('Source and destination accounts cannot be the same.', 16, 1); ROLLBACK; RETURN; END;

        DECLARE @FromBal    DECIMAL(15,2);
        DECLARE @FromMinBal DECIMAL(15,2);
        DECLARE @ToBal      DECIMAL(15,2);

        SELECT @FromBal = a.Balance, @FromMinBal = at.MinBalance
        FROM   Accounts a JOIN AccountTypes at ON a.AccountTypeID = at.AccountTypeID
        WHERE  a.AccountID = @FromAccountID AND a.AccountStatus = 'Active';

        IF @FromBal IS NULL
        BEGIN RAISERROR('Source account %d not found or inactive.', 16, 1, @FromAccountID); ROLLBACK; RETURN; END;

        SELECT @ToBal = Balance FROM Accounts
        WHERE  AccountID = @ToAccountID AND AccountStatus = 'Active';

        IF @ToBal IS NULL
        BEGIN RAISERROR('Destination account %d not found or inactive.', 16, 1, @ToAccountID); ROLLBACK; RETURN; END;

        IF (@FromBal - @Amount) < @FromMinBal
        BEGIN RAISERROR('Insufficient balance for transfer. Available: %.2f', 16, 1, @FromBal); ROLLBACK; RETURN; END;

        -- Debit leg
        INSERT INTO Transactions (AccountID, TransactionType, Amount, BalanceAfter, ReferenceID, Remarks, Channel)
        VALUES (@FromAccountID, 'Withdrawal', @Amount, @FromBal - @Amount,
                CAST(@ToAccountID AS VARCHAR), 'TRF TO:' + @Remarks, @Channel);

        -- Credit leg
        INSERT INTO Transactions (AccountID, TransactionType, Amount, BalanceAfter, ReferenceID, Remarks, Channel)
        VALUES (@ToAccountID, 'Deposit', @Amount, @ToBal + @Amount,
                CAST(@FromAccountID AS VARCHAR), 'TRF FROM:' + @Remarks, @Channel);

        COMMIT;
        PRINT 'Transfer of INR ' + CAST(@Amount AS VARCHAR) + ' completed successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-006: sp_ApplyLoan
-- Req: Loan application. Uses fn_CalculateEMI. KYC check enforced.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_ApplyLoan
    @CustomerID      INT,
    @BranchID        INT,
    @LoanType        VARCHAR(30),
    @PrincipalAmount DECIMAL(15,2),
    @InterestRate    DECIMAL(5,2),
    @TenureMonths    INT,
    @NewLoanID       INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM Customers
                       WHERE CustomerID = @CustomerID AND IsActive = 1 AND KYCStatus = 'Verified')
        BEGIN RAISERROR('Customer is not eligible for a loan (inactive or KYC not verified).', 16, 1); ROLLBACK; RETURN; END;

        DECLARE @EMI DECIMAL(12,2);
        SET @EMI = dbo.fn_CalculateEMI(@PrincipalAmount, @InterestRate, @TenureMonths);

        INSERT INTO Loans (CustomerID, BranchID, LoanType, PrincipalAmount, InterestRate,
                           TenureMonths, EMIAmount, LoanStatus)
        VALUES (@CustomerID, @BranchID, @LoanType, @PrincipalAmount, @InterestRate,
                @TenureMonths, @EMI, 'Applied');

        SET @NewLoanID = SCOPE_IDENTITY();
        COMMIT;
        PRINT 'Loan applied. Loan ID: ' + CAST(@NewLoanID AS VARCHAR) + ' | Monthly EMI: INR ' + CAST(@EMI AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-007: sp_DisburseLoan
-- Req: Approve + disburse. Auto-create full repayment schedule (BR-012).
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_DisburseLoan
    @LoanID     INT,
    @EmployeeID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @Status       VARCHAR(20);
        DECLARE @Tenure       INT;
        DECLARE @EMIAmount    DECIMAL(12,2);

        SELECT @Status = LoanStatus, @Tenure = TenureMonths, @EMIAmount = EMIAmount
        FROM   Loans WHERE LoanID = @LoanID;

        IF @Status IS NULL
        BEGIN RAISERROR('Loan ID %d not found.', 16, 1, @LoanID); ROLLBACK; RETURN; END;

        IF @Status <> 'Applied'
        BEGIN RAISERROR('Loan status must be Applied to disburse. Current: %s', 16, 1, @Status); ROLLBACK; RETURN; END;

        UPDATE Loans
        SET    LoanStatus = 'Disbursed',
               DisbursedDate = GETDATE(),
               OutstandingAmount = PrincipalAmount
        WHERE  LoanID = @LoanID;

        -- Auto-generate repayment schedule (BR-012)
        DECLARE @i INT = 1;
        WHILE @i <= @Tenure
        BEGIN
            INSERT INTO LoanRepayments (LoanID, EMINumber, DueDate, EMIAmount, Status)
            VALUES (@LoanID, @i, DATEADD(MONTH, @i, GETDATE()), @EMIAmount, 'Pending');
            SET @i = @i + 1;
        END;

        COMMIT;
        PRINT 'Loan ' + CAST(@LoanID AS VARCHAR) + ' disbursed. ' + CAST(@Tenure AS VARCHAR) + ' EMI rows created.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-008: sp_GetAccountStatement
-- Req: Masked statement using fn_MaskAccountNumber + fn_GetAccountStatement TVF.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_GetAccountStatement
    @AccountID INT,
    @FromDate  DATE,
    @ToDate    DATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccNum       VARCHAR(20);
    DECLARE @CustomerName VARCHAR(100);

    SELECT @AccNum = a.AccountNumber,
           @CustomerName = c.FirstName + ' ' + c.LastName
    FROM   Accounts a JOIN Customers c ON a.CustomerID = c.CustomerID
    WHERE  a.AccountID = @AccountID;

    IF @AccNum IS NULL
    BEGIN RAISERROR('Account %d not found.', 16, 1, @AccountID); RETURN; END;

    PRINT '====================================';
    PRINT 'ACCOUNT STATEMENT';
    PRINT 'Account : ' + dbo.fn_MaskAccountNumber(@AccNum);  -- BR-016
    PRINT 'Customer: ' + @CustomerName;
    PRINT 'Period  : ' + CAST(@FromDate AS VARCHAR) + ' to ' + CAST(@ToDate AS VARCHAR);
    PRINT '====================================';

    SELECT
        TransactionDate,
        TransactionType,
        CASE WHEN TransactionType IN ('Deposit','Interest') THEN Amount ELSE NULL END  AS Credit,
        CASE WHEN TransactionType IN ('Withdrawal','Charge') THEN Amount ELSE NULL END AS Debit,
        BalanceAfter                                                                   AS RunningBalance,
        Channel,
        ISNULL(Remarks, '-') AS Remarks,
        ProcessedBy
    FROM dbo.fn_GetAccountStatement(@AccountID, @FromDate, @ToDate)
    ORDER BY TransactionDate;
END;
GO

-- ════════════════════════════════════════════════
-- SP-009: sp_BranchPerformanceReport
-- Req: CURSOR — iterate branches, PRINT per-branch KPIs, return result set.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_BranchPerformanceReport
    @BranchID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurBranchID   INT;
    DECLARE @CurName       VARCHAR(100);
    DECLARE @CurAccts      INT;
    DECLARE @CurDeposits   DECIMAL(15,2);
    DECLARE @CurLoans      DECIMAL(15,2);

    -- CUR-001: Branch Performance Cursor
    DECLARE branch_cursor CURSOR FOR
        SELECT BranchID, BranchName, TotalAccounts, TotalDeposits, TotalLoanAmount
        FROM   vw_BranchPerformance
        WHERE  (@BranchID IS NULL OR BranchID = @BranchID);

    OPEN branch_cursor;
    FETCH NEXT FROM branch_cursor INTO @CurBranchID, @CurName, @CurAccts, @CurDeposits, @CurLoans;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '----------------------------------------';
        PRINT 'Branch  : ' + @CurName + ' (ID: ' + CAST(@CurBranchID AS VARCHAR) + ')';
        PRINT 'Accounts: ' + CAST(@CurAccts AS VARCHAR);
        PRINT 'Deposits: INR ' + FORMAT(@CurDeposits, 'N2');
        PRINT 'Loans   : INR ' + FORMAT(@CurLoans, 'N2');
        FETCH NEXT FROM branch_cursor INTO @CurBranchID, @CurName, @CurAccts, @CurDeposits, @CurLoans;
    END;

    CLOSE branch_cursor;
    DEALLOCATE branch_cursor;

    PRINT '----------------------------------------';

    -- Return tabular result set
    SELECT * FROM vw_BranchPerformance
    WHERE  (@BranchID IS NULL OR BranchID = @BranchID)
    ORDER BY TotalDeposits DESC;
END;
GO

-- ════════════════════════════════════════════════
-- SP-010: sp_ApplyMonthlyInterest
-- Req: CURSOR — credit monthly interest to all active savings accounts (BR-014).
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_ApplyMonthlyInterest
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AccID        INT;
        DECLARE @Balance      DECIMAL(15,2);
        DECLARE @Rate         DECIMAL(5,2);
        DECLARE @Interest     DECIMAL(12,2);
        DECLARE @TotalAccts   INT          = 0;
        DECLARE @TotalInterest DECIMAL(15,2) = 0;

        -- CUR-002: Monthly Interest Cursor
        DECLARE interest_cursor CURSOR FOR
            SELECT a.AccountID, a.Balance, at.InterestRate
            FROM   Accounts a
            JOIN   AccountTypes at ON a.AccountTypeID = at.AccountTypeID
            WHERE  a.AccountStatus = 'Active'
            AND    at.TypeName IN ('Savings', 'Zero Balance')
            AND    at.InterestRate > 0;

        OPEN interest_cursor;
        FETCH NEXT FROM interest_cursor INTO @AccID, @Balance, @Rate;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @Interest = ROUND(@Balance * @Rate / 12.0 / 100.0, 2);

            INSERT INTO Transactions (AccountID, TransactionType, Amount, BalanceAfter, Remarks, Channel)
            VALUES (@AccID, 'Interest', @Interest, @Balance + @Interest,
                    'Monthly interest credit', 'System');

            SET @TotalAccts    = @TotalAccts + 1;
            SET @TotalInterest = @TotalInterest + @Interest;

            FETCH NEXT FROM interest_cursor INTO @AccID, @Balance, @Rate;
        END;

        CLOSE interest_cursor;
        DEALLOCATE interest_cursor;

        COMMIT;
        PRINT 'Interest applied to ' + CAST(@TotalAccts AS VARCHAR) + ' accounts.';
        PRINT 'Total interest credited: INR ' + FORMAT(@TotalInterest, 'N2');
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF CURSOR_STATUS('local','interest_cursor') >= 0
        BEGIN CLOSE interest_cursor; DEALLOCATE interest_cursor; END;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-011: sp_MarkDormantAccounts
-- Req: CURSOR — detect and mark accounts inactive 365+ days (BR-013).
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_MarkDormantAccounts
    @InactiveDays INT = 365
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @AccID       INT;
        DECLARE @LastTxn     DATETIME;
        DECLARE @DaysSince   INT;
        DECLARE @DormantCnt  INT = 0;

        -- CUR-003: Dormancy Detection Cursor
        DECLARE dormant_cursor CURSOR FOR
            SELECT a.AccountID, MAX(t.TransactionDate) AS LastTxnDate
            FROM   Accounts a
            LEFT JOIN Transactions t ON a.AccountID = t.AccountID
            WHERE  a.AccountStatus = 'Active'
            GROUP BY a.AccountID;

        OPEN dormant_cursor;
        FETCH NEXT FROM dormant_cursor INTO @AccID, @LastTxn;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @DaysSince = DATEDIFF(DAY, ISNULL(@LastTxn, '2000-01-01'), GETDATE());

            IF @DaysSince >= @InactiveDays
            BEGIN
                UPDATE Accounts SET AccountStatus = 'Dormant' WHERE AccountID = @AccID;

                INSERT INTO AuditLog (TableName, OperationType, RecordID, OldValue, NewValue)
                VALUES ('Accounts', 'UPDATE', @AccID,
                        'Status:Active',
                        'Status:Dormant|DaysInactive:' + CAST(@DaysSince AS VARCHAR));

                SET @DormantCnt = @DormantCnt + 1;
            END;

            FETCH NEXT FROM dormant_cursor INTO @AccID, @LastTxn;
        END;

        CLOSE dormant_cursor;
        DEALLOCATE dormant_cursor;

        COMMIT;
        PRINT CAST(@DormantCnt AS VARCHAR) + ' accounts marked Dormant.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        IF CURSOR_STATUS('local','dormant_cursor') >= 0
        BEGIN CLOSE dormant_cursor; DEALLOCATE dormant_cursor; END;
        RAISERROR(ERROR_MESSAGE(), 16, 1);
    END CATCH;
END;
GO

-- ════════════════════════════════════════════════
-- SP-012: sp_CustomerFullReport
-- Req: 360° customer report — encapsulates ALL object types in one SP.
-- Returns 5 result sets: Profile, Accounts, Transactions, Loans, Cards.
-- ════════════════════════════════════════════════
CREATE PROCEDURE sp_CustomerFullReport
    @CustomerID INT
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Customer Profile (uses fn_CalculateAge)
    SELECT
        CustomerID,
        FirstName + ' ' + LastName              AS FullName,
        Email,
        PhoneNumber,
        KYCStatus,
        dbo.fn_CalculateAge(DateOfBirth)         AS Age,
        DateOfBirth,
        City + ', ' + State                     AS Location
    FROM Customers WHERE CustomerID = @CustomerID;

    -- 2. Account Portfolio (uses fn_GetCustomerPortfolio TVF)
    SELECT * FROM dbo.fn_GetCustomerPortfolio(@CustomerID);

    -- 3. 6-Month Transaction Summary (uses fn_GetAccountStatement TVF)
    SELECT
        TransactionType,
        COUNT(*)       AS TxnCount,
        SUM(Amount)    AS TotalAmount,
        MAX(Amount)    AS MaxTransaction,
        MIN(Amount)    AS MinTransaction
    FROM dbo.fn_GetAccountStatement(
            (SELECT TOP 1 AccountID FROM Accounts
             WHERE CustomerID = @CustomerID AND AccountStatus = 'Active'),
            DATEADD(MONTH, -6, GETDATE()),
            GETDATE()
         )
    GROUP BY TransactionType;

    -- 4. Loan Portfolio (uses vw_LoanPortfolio view)
    SELECT LoanID, LoanType, PrincipalAmount, OutstandingAmount,
           LoanStatus, EMIAmount, MonthsElapsed
    FROM   vw_LoanPortfolio
    WHERE  BorrowerName = (SELECT FirstName + ' ' + LastName
                           FROM Customers WHERE CustomerID = @CustomerID);

    -- 5. Cards with masked card numbers (uses fn_MaskAccountNumber)
    SELECT
        c.CardType,
        dbo.fn_MaskAccountNumber(c.CardNumber) AS MaskedCardNumber,
        c.ExpiryDate,
        c.CardStatus,
        c.CreditLimit
    FROM   Cards c
    JOIN   Accounts a ON c.AccountID = a.AccountID
    WHERE  a.CustomerID = @CustomerID;
END;
GO

PRINT '✔ All 12 Stored Procedures created (includes 3 Cursors: CUR-001, CUR-002, CUR-003).';
GO
