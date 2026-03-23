-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: triggers/07_triggers.sql
-- Description: 4 Triggers (AFTER INSERT, INSTEAD OF DELETE, AFTER UPDATE)
-- ============================================================

USE BankingDB;
GO

-- ────────────────────────────────────────────────
-- TRG-001: trg_AfterTransactionInsert
-- Event  : AFTER INSERT on Transactions
-- Rule   : BR-006 — Balance updated ONLY via trigger, never directly
-- ────────────────────────────────────────────────
CREATE TRIGGER trg_AfterTransactionInsert
ON Transactions
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    -- Propagate BalanceAfter to parent Account (set-based, handles bulk inserts)
    UPDATE a
    SET    a.Balance = i.BalanceAfter
    FROM   Accounts a
    JOIN   inserted i ON a.AccountID = i.AccountID;

    -- Audit trail
    INSERT INTO AuditLog (TableName, OperationType, RecordID, NewValue)
    SELECT
        'Transactions',
        'INSERT',
        TransactionID,
        'AccID:'  + CAST(AccountID AS VARCHAR)   +
        '|Type:'  + TransactionType              +
        '|Amt:'   + CAST(Amount AS VARCHAR)      +
        '|Bal:'   + CAST(BalanceAfter AS VARCHAR)
    FROM inserted;
END;
GO

-- ────────────────────────────────────────────────
-- TRG-002: trg_InsteadOfDeleteAccount
-- Event  : INSTEAD OF DELETE on Accounts
-- Rule   : BR-008 — No physical deletes; BR-009 — non-zero balance blocks close
-- ────────────────────────────────────────────────
CREATE TRIGGER trg_InsteadOfDeleteAccount
ON Accounts
INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @AccountID INT;
    DECLARE @Balance   DECIMAL(15,2);
    SELECT @AccountID = AccountID, @Balance = Balance FROM deleted;

    -- Block close if balance > 0
    IF @Balance > 0
    BEGIN
        RAISERROR('Cannot close account with non-zero balance. Current balance: %f', 16, 1, @Balance);
        RETURN;
    END;

    -- Soft delete: mark as Closed
    UPDATE Accounts
    SET    AccountStatus = 'Closed',
           ClosedDate    = GETDATE()
    WHERE  AccountID IN (SELECT AccountID FROM deleted);

    -- Audit
    INSERT INTO AuditLog (TableName, OperationType, RecordID, OldValue)
    SELECT
        'Accounts', 'DELETE', AccountID,
        'Status:Active|Balance:' + CAST(Balance AS VARCHAR)
    FROM deleted;
END;
GO

-- ────────────────────────────────────────────────
-- TRG-003: trg_AfterLoanRepaymentUpdate
-- Event  : AFTER UPDATE on LoanRepayments
-- Rule   : BR-011 — Auto-classify NPA after 90 overdue days
-- ────────────────────────────────────────────────
CREATE TRIGGER trg_AfterLoanRepaymentUpdate
ON LoanRepayments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Classify loan as NPA if EMI overdue 90+ days
    UPDATE l
    SET    l.LoanStatus = 'NPA'
    FROM   Loans l
    JOIN   inserted i ON l.LoanID = i.LoanID
    WHERE  i.Status = 'Overdue'
    AND    DATEDIFF(DAY, i.DueDate, GETDATE()) >= 90
    AND    l.LoanStatus = 'Disbursed';

    -- Audit status changes
    INSERT INTO AuditLog (TableName, OperationType, RecordID, OldValue, NewValue)
    SELECT
        'LoanRepayments', 'UPDATE', i.RepaymentID,
        'Status:' + d.Status,
        'Status:' + i.Status
    FROM   inserted i
    JOIN   deleted  d ON i.RepaymentID = d.RepaymentID
    WHERE  i.Status <> d.Status;
END;
GO

-- ────────────────────────────────────────────────
-- TRG-004: trg_AfterCustomerInsert
-- Event  : AFTER INSERT on Customers
-- Rule   : BR-015 — All critical table INSERTs must be audit-logged
-- ────────────────────────────────────────────────
CREATE TRIGGER trg_AfterCustomerInsert
ON Customers
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO AuditLog (TableName, OperationType, RecordID, NewValue)
    SELECT
        'Customers', 'INSERT', CustomerID,
        'Name:'  + FirstName + ' ' + LastName +
        '|Email:' + Email                     +
        '|KYC:'   + KYCStatus
    FROM inserted;
END;
GO

PRINT '✔ All 4 Triggers created.';
GO
