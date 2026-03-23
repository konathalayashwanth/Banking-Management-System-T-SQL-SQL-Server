-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: tables/02_create_tables.sql
-- Description: All 10 core tables with constraints
-- ============================================================

USE BankingDB;
GO

-- ────────────────────────────────────────────────
-- 1. Branches
-- ────────────────────────────────────────────────
CREATE TABLE Branches (
    BranchID       INT IDENTITY(1,1) PRIMARY KEY,
    BranchName     VARCHAR(100) NOT NULL,
    BranchCode     VARCHAR(10)  NOT NULL UNIQUE,
    City           VARCHAR(50)  NOT NULL,
    State          VARCHAR(50)  NOT NULL,
    PhoneNumber    VARCHAR(15),
    IsActive       BIT          NOT NULL DEFAULT 1,
    CreatedDate    DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- ────────────────────────────────────────────────
-- 2. Customers
-- ────────────────────────────────────────────────
CREATE TABLE Customers (
    CustomerID     INT IDENTITY(1,1) PRIMARY KEY,
    FirstName      VARCHAR(50)  NOT NULL,
    LastName       VARCHAR(50)  NOT NULL,
    DateOfBirth    DATE         NOT NULL,
    Gender         CHAR(1)      CHECK (Gender IN ('M','F','O')),
    Email          VARCHAR(100) NOT NULL UNIQUE,
    PhoneNumber    VARCHAR(15)  NOT NULL,
    Address        VARCHAR(200),
    City           VARCHAR(50),
    State          VARCHAR(50),
    PINCode        VARCHAR(10),
    AadhaarNumber  VARCHAR(12)  UNIQUE,
    PANNumber      VARCHAR(10)  UNIQUE,
    KYCStatus      VARCHAR(20)  NOT NULL DEFAULT 'Pending'
                   CHECK (KYCStatus IN ('Pending','Verified','Rejected')),
    IsActive       BIT          NOT NULL DEFAULT 1,
    CreatedDate    DATETIME     NOT NULL DEFAULT GETDATE()
);
GO

-- ────────────────────────────────────────────────
-- 3. Account Types
-- ────────────────────────────────────────────────
CREATE TABLE AccountTypes (
    AccountTypeID   INT IDENTITY(1,1) PRIMARY KEY,
    TypeName        VARCHAR(50)   NOT NULL UNIQUE,
    InterestRate    DECIMAL(5,2)  NOT NULL DEFAULT 0.00,
    MinBalance      DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    Description     VARCHAR(200)
);
GO

-- ────────────────────────────────────────────────
-- 4. Accounts
-- ────────────────────────────────────────────────
CREATE TABLE Accounts (
    AccountID       INT IDENTITY(1,1) PRIMARY KEY,
    AccountNumber   VARCHAR(20)   NOT NULL UNIQUE,
    CustomerID      INT           NOT NULL REFERENCES Customers(CustomerID),
    BranchID        INT           NOT NULL REFERENCES Branches(BranchID),
    AccountTypeID   INT           NOT NULL REFERENCES AccountTypes(AccountTypeID),
    Balance         DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    OpenedDate      DATE          NOT NULL DEFAULT GETDATE(),
    ClosedDate      DATE          NULL,
    AccountStatus   VARCHAR(20)   NOT NULL DEFAULT 'Active'
                    CHECK (AccountStatus IN ('Active','Dormant','Closed','Frozen')),
    IFSC            VARCHAR(15),
    CreatedDate     DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ────────────────────────────────────────────────
-- 5. Employees
-- ────────────────────────────────────────────────
CREATE TABLE Employees (
    EmployeeID      INT IDENTITY(1,1) PRIMARY KEY,
    FirstName       VARCHAR(50)   NOT NULL,
    LastName        VARCHAR(50)   NOT NULL,
    BranchID        INT           NOT NULL REFERENCES Branches(BranchID),
    Designation     VARCHAR(50)   NOT NULL,
    Email           VARCHAR(100)  NOT NULL UNIQUE,
    PhoneNumber     VARCHAR(15),
    Salary          DECIMAL(12,2) NOT NULL,
    JoiningDate     DATE          NOT NULL DEFAULT GETDATE(),
    IsActive        BIT           NOT NULL DEFAULT 1
);
GO

-- ────────────────────────────────────────────────
-- 6. Transactions (append-only ledger)
-- ────────────────────────────────────────────────
CREATE TABLE Transactions (
    TransactionID   INT IDENTITY(1,1) PRIMARY KEY,
    AccountID       INT           NOT NULL REFERENCES Accounts(AccountID),
    TransactionType VARCHAR(20)   NOT NULL
                    CHECK (TransactionType IN ('Deposit','Withdrawal','Transfer','Interest','Charge')),
    Amount          DECIMAL(15,2) NOT NULL CHECK (Amount > 0),
    BalanceAfter    DECIMAL(15,2) NOT NULL,
    ReferenceID     VARCHAR(30)   NULL,
    Remarks         VARCHAR(200),
    TransactionDate DATETIME      NOT NULL DEFAULT GETDATE(),
    ProcessedBy     INT           NULL REFERENCES Employees(EmployeeID),
    Channel         VARCHAR(20)   DEFAULT 'Branch'
                    CHECK (Channel IN ('Branch','ATM','NetBanking','Mobile','UPI'))
);
GO

-- ────────────────────────────────────────────────
-- 7. Loans
-- ────────────────────────────────────────────────
CREATE TABLE Loans (
    LoanID            INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID        INT           NOT NULL REFERENCES Customers(CustomerID),
    BranchID          INT           NOT NULL REFERENCES Branches(BranchID),
    LoanType          VARCHAR(30)   NOT NULL
                      CHECK (LoanType IN ('Home','Personal','Vehicle','Education','Business')),
    PrincipalAmount   DECIMAL(15,2) NOT NULL,
    InterestRate      DECIMAL(5,2)  NOT NULL,
    TenureMonths      INT           NOT NULL,
    EMIAmount         DECIMAL(12,2) NOT NULL,
    DisbursedDate     DATE          NULL,
    LoanStatus        VARCHAR(20)   NOT NULL DEFAULT 'Applied'
                      CHECK (LoanStatus IN ('Applied','Approved','Disbursed','Closed','Rejected','NPA')),
    OutstandingAmount DECIMAL(15,2) NULL,
    CreatedDate       DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

-- ────────────────────────────────────────────────
-- 8. Loan Repayments
-- ────────────────────────────────────────────────
CREATE TABLE LoanRepayments (
    RepaymentID    INT IDENTITY(1,1) PRIMARY KEY,
    LoanID         INT           NOT NULL REFERENCES Loans(LoanID),
    EMINumber      INT           NOT NULL,
    DueDate        DATE          NOT NULL,
    PaidDate       DATE          NULL,
    EMIAmount      DECIMAL(12,2) NOT NULL,
    PrincipalPaid  DECIMAL(12,2) NULL,
    InterestPaid   DECIMAL(12,2) NULL,
    PenaltyCharged DECIMAL(10,2) DEFAULT 0,
    Status         VARCHAR(20)   NOT NULL DEFAULT 'Pending'
                   CHECK (Status IN ('Pending','Paid','Overdue','Waived'))
);
GO

-- ────────────────────────────────────────────────
-- 9. Cards
-- ────────────────────────────────────────────────
CREATE TABLE Cards (
    CardID       INT IDENTITY(1,1) PRIMARY KEY,
    AccountID    INT           NOT NULL REFERENCES Accounts(AccountID),
    CardType     VARCHAR(20)   NOT NULL CHECK (CardType IN ('Debit','Credit','Prepaid')),
    CardNumber   VARCHAR(20)   NOT NULL UNIQUE,
    ExpiryDate   DATE          NOT NULL,
    CardStatus   VARCHAR(20)   NOT NULL DEFAULT 'Active'
                 CHECK (CardStatus IN ('Active','Blocked','Expired','Lost')),
    CreditLimit  DECIMAL(12,2) NULL,
    IssuedDate   DATE          NOT NULL DEFAULT GETDATE()
);
GO

-- ────────────────────────────────────────────────
-- 10. Audit Log (compliance trail)
-- ────────────────────────────────────────────────
CREATE TABLE AuditLog (
    LogID         INT IDENTITY(1,1) PRIMARY KEY,
    TableName     VARCHAR(50)   NOT NULL,
    OperationType VARCHAR(10)   NOT NULL CHECK (OperationType IN ('INSERT','UPDATE','DELETE')),
    RecordID      INT,
    OldValue      NVARCHAR(MAX),
    NewValue      NVARCHAR(MAX),
    ChangedBy     VARCHAR(100)  DEFAULT SYSTEM_USER,
    ChangedAt     DATETIME      NOT NULL DEFAULT GETDATE()
);
GO

PRINT '✔ All 10 tables created successfully.';
GO
