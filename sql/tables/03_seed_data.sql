-- ============================================================
-- BANKING MANAGEMENT SYSTEM
-- File: tables/03_seed_data.sql
-- Description: Sample data for all tables
-- ============================================================

USE BankingDB;
GO

-- Branches
INSERT INTO Branches (BranchName, BranchCode, City, State, PhoneNumber) VALUES
('Hyderabad Main Branch', 'HYD001', 'Hyderabad', 'Telangana',   '040-12345678'),
('Mumbai Central Branch', 'MUM001', 'Mumbai',    'Maharashtra', '022-23456789'),
('Delhi North Branch',    'DEL001', 'Delhi',     'Delhi',       '011-34567890'),
('Bangalore Tech Branch', 'BLR001', 'Bangalore', 'Karnataka',   '080-45678901'),
('Chennai South Branch',  'CHN001', 'Chennai',   'Tamil Nadu',  '044-56789012');
GO

-- Account Types
INSERT INTO AccountTypes (TypeName, InterestRate, MinBalance, Description) VALUES
('Savings',          3.50, 500.00,   'Standard savings account with 3.5% p.a. interest'),
('Current',          0.00, 10000.00, 'Current account for businesses, no interest'),
('Fixed Deposit',    7.00, 1000.00,  'Fixed deposit account with high interest'),
('Recurring Deposit',6.00, 500.00,   'Monthly recurring deposit'),
('Zero Balance',     0.00, 0.00,     'Zero minimum balance savings account');
GO

-- Customers
INSERT INTO Customers (FirstName, LastName, DateOfBirth, Gender, Email, PhoneNumber,
    Address, City, State, PINCode, AadhaarNumber, PANNumber, KYCStatus) VALUES
('Rahul',  'Sharma', '1990-05-15', 'M', 'rahul.sharma@email.com',  '9876543210', '12 MG Road',      'Hyderabad', 'Telangana',   '500001', '123456789012', 'ABCPS1234A', 'Verified'),
('Priya',  'Verma',  '1985-08-22', 'F', 'priya.verma@email.com',   '9876543211', '45 Banjara Hills', 'Hyderabad', 'Telangana',   '500034', '123456789013', 'DEFPV5678B', 'Verified'),
('Arjun',  'Patel',  '1992-11-10', 'M', 'arjun.patel@email.com',   '9876543212', '78 SV Road',      'Mumbai',    'Maharashtra', '400054', '123456789014', 'GHIAP9012C', 'Verified'),
('Sneha',  'Reddy',  '1988-03-18', 'F', 'sneha.reddy@email.com',   '9876543213', '23 Jubilee Hills', 'Hyderabad', 'Telangana',   '500033', '123456789015', 'JKLSR3456D', 'Verified'),
('Vikram', 'Singh',  '1995-07-25', 'M', 'vikram.singh@email.com',  '9876543214', '90 Connaught Pl', 'Delhi',     'Delhi',       '110001', '123456789016', 'MNOSVS789E', 'Pending'),
('Kavya',  'Nair',   '1993-12-05', 'F', 'kavya.nair@email.com',    '9876543215', '34 Koramangala',  'Bangalore', 'Karnataka',   '560034', '123456789017', 'PQRKN1234F', 'Verified'),
('Suresh', 'Kumar',  '1980-01-30', 'M', 'suresh.kumar@email.com',  '9876543216', '67 Anna Nagar',   'Chennai',   'Tamil Nadu',  '600040', '123456789018', 'STUSK5678G', 'Verified'),
('Ananya', 'Gupta',  '1997-09-14', 'F', 'ananya.gupta@email.com',  '9876543217', '11 Lajpat Nagar', 'Delhi',     'Delhi',       '110024', '123456789019', 'VWXAG9012H', 'Verified');
GO

-- Employees
INSERT INTO Employees (FirstName, LastName, BranchID, Designation, Email, PhoneNumber, Salary, JoiningDate) VALUES
('Mohan', 'Rao',    1, 'Branch Manager', 'mohan.rao@bank.com',   '9111111111', 85000.00, '2015-03-01'),
('Divya', 'Lakshmi',1, 'Cashier',        'divya.l@bank.com',     '9111111112', 35000.00, '2018-06-15'),
('Ravi',  'Teja',   2, 'Branch Manager', 'ravi.teja@bank.com',   '9111111113', 85000.00, '2014-09-01'),
('Pooja', 'Mehta',  2, 'Loan Officer',   'pooja.mehta@bank.com', '9111111114', 50000.00, '2019-01-10'),
('Sanjay','Bhat',   3, 'Branch Manager', 'sanjay.bhat@bank.com', '9111111115', 85000.00, '2013-07-01');
GO

-- Accounts
INSERT INTO Accounts (AccountNumber, CustomerID, BranchID, AccountTypeID, Balance, IFSC) VALUES
('ACC1000000001', 1, 1, 1,  50000.00, 'BANK0HYD001'),
('ACC1000000002', 2, 1, 1, 125000.00, 'BANK0HYD001'),
('ACC1000000003', 3, 2, 2, 500000.00, 'BANK0MUM001'),
('ACC1000000004', 4, 1, 1,  75000.00, 'BANK0HYD001'),
('ACC1000000005', 5, 3, 1,  30000.00, 'BANK0DEL001'),
('ACC1000000006', 6, 4, 1, 200000.00, 'BANK0BLR001'),
('ACC1000000007', 7, 5, 2, 350000.00, 'BANK0CHN001'),
('ACC1000000008', 8, 3, 1,  15000.00, 'BANK0DEL001');
GO

-- Transactions
INSERT INTO Transactions (AccountID, TransactionType, Amount, BalanceAfter, Remarks, ProcessedBy, Channel) VALUES
(1, 'Deposit',    10000.00,  50000.00, 'Initial deposit',         1, 'Branch'),
(1, 'Withdrawal',  5000.00,  45000.00, 'ATM withdrawal',       NULL, 'ATM'),
(2, 'Deposit',    25000.00, 125000.00, 'Salary credit',        NULL, 'NetBanking'),
(3, 'Deposit',   100000.00, 500000.00, 'Business deposit',        3, 'Branch'),
(4, 'Deposit',    20000.00,  75000.00, 'Fund transfer received',  1, 'Mobile'),
(5, 'Withdrawal', 10000.00,  30000.00, 'ATM withdrawal',       NULL, 'ATM'),
(6, 'Deposit',    50000.00, 200000.00, 'Investment deposit',   NULL, 'NetBanking'),
(1, 'Deposit',     5000.00,  50000.00, 'Cash deposit',            2, 'Branch');
GO

-- Loans
INSERT INTO Loans (CustomerID, BranchID, LoanType, PrincipalAmount, InterestRate,
    TenureMonths, EMIAmount, DisbursedDate, LoanStatus, OutstandingAmount) VALUES
(1, 1, 'Home',      5000000.00, 8.50, 240, 43391.00, '2023-01-15', 'Disbursed', 4850000.00),
(2, 1, 'Personal',   500000.00,12.00,  36, 16607.00, '2023-06-01', 'Disbursed',  350000.00),
(3, 2, 'Vehicle',    800000.00, 9.50,  60, 16693.00, '2023-03-10', 'Disbursed',  650000.00),
(4, 1, 'Education',  300000.00, 7.50,  48,  7257.00, '2022-08-01', 'Disbursed',  180000.00),
(5, 3, 'Personal',   200000.00,13.00,  24,  9519.00,         NULL, 'Applied',          NULL);
GO

-- Cards
INSERT INTO Cards (AccountID, CardType, CardNumber, ExpiryDate, CardStatus, CreditLimit) VALUES
(1, 'Debit',  '4111111111111111', '2027-12-31', 'Active',      NULL),
(2, 'Debit',  '4111111111112222', '2026-08-31', 'Active',      NULL),
(3, 'Credit', '5500000000001111', '2027-06-30', 'Active', 100000.00),
(4, 'Debit',  '4111111111113333', '2028-03-31', 'Active',      NULL),
(6, 'Credit', '5500000000002222', '2026-11-30', 'Active', 200000.00);
GO

PRINT '✔ Sample data inserted successfully.';
GO
