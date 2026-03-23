# 🏦 Banking Management System — T-SQL / SQL Server

> A production-grade banking backend built entirely in **T-SQL on Microsoft SQL Server**, designed from a formal **Business Requirements Document (BRD)**.  
> Every database object has a traceable business justification.

---

## 📋 Table of Contents
- [Project Overview](#-project-overview)
- [Tech Stack](#-tech-stack)
- [Database Object Inventory](#-database-object-inventory)
- [Project Structure](#-project-structure)
- [Entity Relationship Overview](#-entity-relationship-overview)
- [Business Rules Enforced](#-business-rules-enforced)
- [How to Run](#-how-to-run)
- [Key Highlights](#-key-highlights)
- [Sample Outputs](#-sample-outputs)
- [Documentation](#-documentation)

---

## 🎯 Project Overview

The **Banking Management System** is a complete SQL Server backend that simulates core banking operations:

| Module | Operations |
|--------|-----------|
| **Customer Management** | Registration, KYC verification, age validation |
| **Account Management** | Open account, deposit, withdraw, fund transfer, dormancy |
| **Loan Module** | Apply, disburse, EMI schedule generation, NPA detection |
| **Transaction Ledger** | Immutable append-only financial ledger |
| **Card Management** | Debit/Credit card issuance and status |
| **Reporting** | Branch KPIs, account statements, customer 360 |
| **Audit & Compliance** | Full audit trail, soft deletes, masked account numbers |

---

## 🛠 Tech Stack

| Component | Technology |
|-----------|-----------|
| Database | Microsoft SQL Server 2019+ |
| Language | T-SQL |
| IDE | SQL Server Management Studio (SSMS) |
| Design | Based on formal BRD from Business Analyst |

---

## 📦 Database Object Inventory

| # | Object Type | Count | Objects |
|---|-------------|-------|---------|
| 1 | **Tables** | 10 | Branches, Customers, AccountTypes, Accounts, Employees, Transactions, Loans, LoanRepayments, Cards, AuditLog |
| 2 | **Scalar Functions** | 5 | fn_CalculateAge, fn_CalculateEMI, fn_MaskAccountNumber, fn_GetAccountBalance, fn_CheckMinBalance |
| 3 | **Table-Valued Functions** | 4 | fn_GetAccountStatement *(inline)*, fn_GetCustomerPortfolio *(inline)*, fn_GenerateLoanSchedule *(multi-stmt)*, fn_GetOverdueLoans *(inline)* |
| 4 | **Standard Views** | 4 | vw_CustomerAccountSummary, vw_BranchPerformance, vw_DailyTransactionSummary, vw_LoanPortfolio |
| 5 | **Indexed Views** *(Materialized)* | 2 | vw_BranchBalanceSummary, vw_MaterializedTxnSummary |
| 6 | **Triggers** | 4 | AFTER INSERT, INSTEAD OF DELETE, AFTER UPDATE, AFTER INSERT (audit) |
| 7 | **Stored Procedures** | 12 | sp_CreateCustomer, sp_OpenAccount, sp_Deposit, sp_Withdraw, sp_FundTransfer, sp_ApplyLoan, sp_DisburseLoan, sp_GetAccountStatement, sp_BranchPerformanceReport, sp_ApplyMonthlyInterest, sp_MarkDormantAccounts, sp_CustomerFullReport |
| 8 | **Cursors** | 3 | Inside SP-009, SP-010, SP-011 |
| | **TOTAL** | **44 objects** | |

---

## 📁 Project Structure

```
banking-management-system/
├── 📄 README.md
├── 📄 Banking_BRD.docx               ← Full Business Requirements Document
│
├── sql/
│   ├── 01_create_database.sql        ← Database creation
│   │
│   ├── tables/
│   │   ├── 02_create_tables.sql      ← All 10 tables with constraints
│   │   └── 03_seed_data.sql          ← Sample data (8 customers, branches, loans...)
│   │
│   ├── functions/
│   │   ├── 04_scalar_functions.sql   ← 5 scalar functions
│   │   └── 05_table_valued_functions.sql ← 4 TVFs (inline + multi-statement)
│   │
│   ├── views/
│   │   └── 06_views.sql              ← 4 standard + 2 indexed (materialized) views
│   │
│   ├── triggers/
│   │   └── 07_triggers.sql           ← 4 triggers (AFTER INSERT, INSTEAD OF DELETE, AFTER UPDATE)
│   │
│   └── stored_procedures/
│       └── 08_stored_procedures.sql  ← 12 SPs enclosing all objects + 3 cursors
│
└── scripts/
    ├── 00_master_install.sql         ← ONE-CLICK full installation
    └── 09_run_demo.sql               ← Demo execution & verification
```

---

## 🗄 Entity Relationship Overview

```
Branches  ──< Accounts  ──< Transactions
              Accounts  ──< Cards
Customers ──< Accounts
Customers ──< Loans     ──< LoanRepayments
Branches  ──< Employees
Branches  ──< Loans
[All tables] ──> AuditLog  (via Triggers)
```

---

## ✅ Business Rules Enforced

| Rule | Enforcement |
|------|-------------|
| Customer age ≥ 18 | `fn_CalculateAge` inside `sp_CreateCustomer` |
| KYC must be Verified before account/loan | Validation in `sp_OpenAccount`, `sp_ApplyLoan` |
| Balance never directly updated | `trg_AfterTransactionInsert` owns all balance updates |
| Account cannot be physically deleted | `trg_InsteadOfDeleteAccount` (soft close) |
| Non-zero balance blocks account close | Checked inside INSTEAD OF trigger |
| Fund transfer is fully atomic | Single transaction wrapping both legs in `sp_FundTransfer` |
| EMI computed by standard formula | `fn_CalculateEMI` called at loan creation |
| Loan 90+ days overdue → NPA | `trg_AfterLoanRepaymentUpdate` auto-classifies |
| Account number always masked | `fn_MaskAccountNumber` in all output SPs |
| All changes audit-logged | 4 triggers writing to `AuditLog` |

---

## 🚀 How to Run

### Prerequisites
- Microsoft SQL Server 2019 or later
- SQL Server Management Studio (SSMS) 18+

### Quick Install (Recommended)

Open `scripts/00_master_install.sql` in SSMS and press **F5**.

This runs all 8 scripts in the correct dependency order.

### Manual Step-by-Step

```sql
-- Run in order:
1. sql/01_create_database.sql
2. sql/tables/02_create_tables.sql
3. sql/tables/03_seed_data.sql
4. sql/functions/04_scalar_functions.sql
5. sql/functions/05_table_valued_functions.sql
6. sql/views/06_views.sql
7. sql/triggers/07_triggers.sql
8. sql/stored_procedures/08_stored_procedures.sql

-- Verify:
9. scripts/09_run_demo.sql
```

---

## ✨ Key Highlights

### Stored Procedures encapsulate ALL objects
```sql
-- sp_CustomerFullReport uses every object type in one call:
EXEC sp_CustomerFullReport @CustomerID = 1;
-- Returns: customer profile (scalar fn) + accounts (TVF) +
--          transactions (TVF) + loans (view) + cards (scalar fn)
```

### Indexed (Materialized) Views
```sql
-- SQL Server materialized view — pre-computed at write time
SELECT * FROM vw_BranchBalanceSummary WITH (NOEXPAND);
SELECT * FROM vw_MaterializedTxnSummary WITH (NOEXPAND);
```

### EMI Calculation Scalar Function
```sql
-- Standard formula: P * r * (1+r)^n / ((1+r)^n - 1)
SELECT dbo.fn_CalculateEMI(500000, 12.00, 36) AS MonthlyEMI;
-- Result: 16607.00
```

### INSTEAD OF Trigger (Soft Delete)
```sql
-- This physically deletes — but the trigger converts it to a soft close
DELETE FROM Accounts WHERE AccountID = 1;
-- Result: AccountStatus = 'Closed', ClosedDate = today (no row removed)
```

### Multi-Statement TVF — Loan Amortisation Schedule
```sql
SELECT * FROM dbo.fn_GenerateLoanSchedule(1);
-- Returns 240 rows showing principal/interest split per EMI
```

---

## 📊 Sample Outputs

### Account Statement
```
====================================
ACCOUNT STATEMENT
Account : XXXXXXXXX0001    ← masked per PCI-DSS
Customer: Rahul Sharma
Period  : 2024-01-01 to 2026-12-31
====================================
| Date       | Type       | Credit  | Debit  | Balance  |
| 2024-01-15 | Deposit    | 10000   | NULL   | 50000.00 |
| 2024-02-01 | Withdrawal | NULL    | 5000   | 45000.00 |
```

### Branch Performance Report (Cursor Output)
```
Branch  : Hyderabad Main Branch (ID: 1)
Accounts: 3
Deposits: INR 2,50,000.00
Loans   : INR 57,00,000.00
```

---

## 📄 Documentation

A full **Business Requirements Document (BRD)** (`Banking_BRD.docx`) is included containing:

- Executive Summary & Project Scope
- Stakeholder Matrix
- Business Glossary (KYC, NPA, EMI, IFSC...)
- Column-level schema specs with BA justifications
- Requirement specs for every function, view, trigger, and stored procedure
- Business Rules (BR-001 to BR-016)
- Developer Acceptance Criteria

---

## 👨‍💻 Author

Built as a complete T-SQL portfolio project demonstrating real-world banking domain knowledge with enterprise-grade SQL Server development patterns.

---

## 📌 Tags

`T-SQL` `SQL Server` `Stored Procedures` `Triggers` `Cursors` `Indexed Views` `Banking Domain` `Database Design` `BRD` `Table-Valued Functions`
