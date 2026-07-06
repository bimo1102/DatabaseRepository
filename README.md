# Database Administration & Development Documentation (Database Repository)

> **Standardized documentation for Database Engineers, Architects, and Developers**

Welcome to the Database Repository. This is the Single Source of Truth for managing, maintaining, and developing all databases within the system. This document is designed following the strictest Enterprise-Grade standards to ensure stability, scalability, and maximum performance.

---

## 📑 Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Database Design](#2-database-design)
3. [Repository Structure](#3-repository-structure)
4. [SQL Migration Strategy](#4-sql-migration-strategy)
5. [Domain Example (Account)](#5-domain-example-account)
6. [SQL Standards](#6-sql-standards)
7. [Docker Environment](#7-docker-environment)
8. [DBeaver Management](#8-dbeaver-management)
9. [Development Workflow](#9-development-workflow)
10. [Git Workflow](#10-git-workflow)
11. [Backup & Restore](#11-backup--restore)
12. [Troubleshooting](#12-troubleshooting)
13. [Frequently Asked Questions (FAQ)](#13-frequently-asked-questions-faq)
14. [Best Practices](#14-best-practices)

---

## 1. Architecture Overview

Our system is designed based on the **CQRS (Command Query Responsibility Segregation)** pattern combined with **Domain-Driven Design (DDD)**.

### Technologies Used:
- **Write Database (Command):** SQL Server
- **Read Database (Query):** PostgreSQL
- **Management Tool:** DBeaver
- **Dev Environment Deployment:** Docker & Docker Compose

> [!IMPORTANT]
> **DO NOT USE ENTITY FRAMEWORK (EF)** to create or migrate databases. 
> **DO NOT USE EF MIGRATIONS**.
> All schema changes must be executed using pure SQL Migration files.

### Why Did We Choose This Architecture?
1. **Clear Separation of Concerns (CQRS):** Separating the write system (optimized for transactions, ACID) and the read system (optimized for query speed, flat data) allows the system to scale independently with ease. SQL Server handles transactions extremely well thanks to its lock management, while PostgreSQL provides powerful JSONB processing and indexing capabilities, making it a perfect fit for the Read Model.
2. **Total Control (No ORM Migrations):** EF Migrations generate suboptimal SQL commands automatically and hide table lock risks in production environments. Managing via pure SQL helps DBAs and Developers control 100% of how data changes, optimizing indexes and transactions.
3. **Domain Independence (DDD):** Each domain is an isolated island, completely preventing "Spaghetti Databases".

---

## 2. Database Design

Each Business Domain owns its own independent database.

Example domains: `Account`, `Product`, `Purchase`, `Sender`, `Medical`, `General`, `Notification`, etc.

Each Domain will have 2 physical (or logical depending on environment) databases:
- `<Domain>_Write` (SQL Server)
- `<Domain>_Read` (PostgreSQL)

### Core Design Rules:
> [!CAUTION]
> - **Total Independence:** No tables are shared across domains.
> - **No Cross-Domain Foreign Keys:** Domains communicate with each other using an Event/Message Broker or APIs. You must absolutely not create a Foreign Key linking a table in the Account Domain to the Product Domain.
> - **Eventual Consistency Principle:** Data from the Write DB will be synchronized to the Read DB via an Event Worker.

---

## 3. Repository Structure

The directory structure is designed for easy scalability and version management.

```text
DatabaseRepository/
├── .dbeaver/                  # DBeaver project configuration
├── docker/                    # Docker configuration files
│   ├── docker-compose.yml
│   └── init-scripts/          # Shell scripts to init databases on docker start
├── domains/                   # Contains all domains
│   ├── Account/               
│   │   ├── Write_SQLServer/   # Migrations for Account Write DB
│   │   │   ├── migrations/    # SQL files for schema changes
│   │   │   └── seeds/         # Sample data (master data)
│   │   └── Read_PostgreSQL/   # Migrations for Account Read DB
│   │       ├── migrations/
│   │       └── seeds/
│   ├── Product/               # Structure similar to Account
│   └── ...
├── docs/                      # Detailed docs, ERD, Data dictionary
└── README.md                  # This document
```

---

## 4. SQL Migration Strategy

We use an **Immutable Migrations** strategy.

### Inviolable Principle:
> [!WARNING]
> **ONCE A MIGRATION IS MERGED INTO THE `main` BRANCH, YOU MUST ABSOLUTELY NEVER MODIFY THAT FILE.**

**Reason:** When a file runs in Production, the schema has already changed. If you edit an old file, the migration tool won't know to rerun it (or it will throw a checksum mismatch error). All changes (adding columns, altering data types) **MUST** be performed by creating a new migration file.

### Migration Naming Convention:
Format: `V<Version>__<Description>.sql` (e.g., Flyway naming convention).

**Correct Examples:**
- `V001__Create_User_Table.sql`
- `V002__Add_Email_Column.sql`
- `V003__Add_Index_Email.sql`

**Incorrect Examples (Strictly Forbidden):**
- Opening `V001__Create_User_Table.sql` and adding an `Email` column.

---

## 5. Domain Example (Account)

The `Account` domain manages user identities.

### 5.1 Write Model (SQL Server)
The write model is normalized (3NF) to ensure data integrity and ACID properties.

**File:** `domains/Account/Write_SQLServer/migrations/V001__Create_User.sql`

```sql
-- SQL Server
CREATE TABLE [dbo].[Users] (
    [Id] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    [UserName] NVARCHAR(256) NOT NULL,
    [EmailAddress] NVARCHAR(256) NULL,
    [Password] NVARCHAR(MAX) NULL,
    [PasswordSalt] NVARCHAR(256) NULL,
    [PhoneNumber] VARCHAR(20) NULL,
    [Status] TINYINT NOT NULL DEFAULT 1, -- 1: Active, 0: Inactive
    [CreatedDate] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    [UpdatedDate] DATETIME2 NULL,
    [RowVersion] ROWVERSION NOT NULL, -- For Optimistic Concurrency
    CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [UQ_Users_UserName] UNIQUE ([UserName])
);

CREATE TABLE [dbo].[UserInformations] (
    [Id] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWSEQUENTIALID(),
    [UserId] UNIQUEIDENTIFIER NOT NULL,
    [FullName] NVARCHAR(256) NULL,
    [DateOfBirth] DATE NULL,
    [Gender] TINYINT NULL, -- 1: Male, 2: Female, 3: Other
    [IdentificationNumber] VARCHAR(50) NULL,
    [CompanyName] NVARCHAR(256) NULL,
    [CreatedDate] DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    [UpdatedDate] DATETIME2 NULL,
    CONSTRAINT [PK_UserInformations] PRIMARY KEY CLUSTERED ([Id]),
    CONSTRAINT [FK_UserInformations_Users] FOREIGN KEY ([UserId]) REFERENCES [dbo].[Users]([Id]) ON DELETE CASCADE,
    CONSTRAINT [UQ_UserInformations_UserId] UNIQUE ([UserId]) -- 1-1 Relationship
);

CREATE NONCLUSTERED INDEX [IX_Users_EmailAddress] ON [dbo].[Users]([EmailAddress]) WHERE [EmailAddress] IS NOT NULL;
```

**Write Model Explanation:**
- **Users**: Stores core information used for login and security.
- **UserInformations**: Stores detailed information that can be frequently updated without impacting locks on the Users table.
- **RowVersion**: Used to handle Optimistic Concurrency (prevents data loss when 2 users update simultaneously).

### 5.2 Read Model (PostgreSQL)
The read model is denormalized to minimize the number of JOINs and provide immediate data for Read APIs.

**File:** `domains/Account/Read_PostgreSQL/migrations/V001__Create_UserReadModel.sql`

```sql
-- PostgreSQL
CREATE TABLE users_read (
    id UUID PRIMARY KEY,
    username VARCHAR(256) NOT NULL,
    email_address VARCHAR(256),
    phone_number VARCHAR(20),
    status SMALLINT NOT NULL,
    
    -- Denormalized data from UserInformation
    full_name VARCHAR(256),
    date_of_birth DATE,
    gender SMALLINT,
    identification_number VARCHAR(50),
    company_name VARCHAR(256),
    
    last_login_time TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_users_read_email ON users_read(email_address);
CREATE INDEX idx_users_read_fullname_trgm ON users_read USING GIN (full_name gin_trgm_ops); -- Supports full-text search
```

**Read Model Explanation:**
- Combines `User` and `UserInformation` into a flat table `users_read`. When an API requests Account information, a simple `SELECT *` is sufficient, with no `JOIN` required.
- Columns like `Password`, `PasswordSalt`, or `RowVersion` are excluded because the Read Model does not serve logins or process transactions.
- Supports GIN Indexes for high-speed text search features.

---

## 6. SQL Standards

The system requires strict conventions to ensure consistency.

| Element | Convention | Explanation & Reason (Why) |
|---|---|---|
| **Database Naming** | `PascalCase` (e.g., `Account_Write`, `Product_Read`) | Easily identifiable, syncs with Domain names in C# code. |
| **Schema Naming** | SQL Server: `dbo`. Postgres: `public` or by context | Keep defaults to reduce complexity during permission assignment. |
| **Table Naming** | `PascalCase`, plural (e.g., `Users`, `Products`) <br/> Postgres: `snake_case`, plural (e.g., `users_read`) | Traditional SQL Server uses PascalCase. Postgres always uses lowercase + snake_case to prevent annoying case-sensitivity query errors. |
| **Column Naming** | SQL Server: `PascalCase`<br/>Postgres: `snake_case` | Syncs with Table Naming. |
| **Primary Keys** | Column `Id`. Constraint: `PK_<TableName>` | Easily maps with BaseDomain `Id`. Clear constraint names make debugging easy. |
| **Foreign Keys** | Column Name: `<TableName>Id` (e.g., `UserId`).<br/> Constraint: `FK_<Table>_<RefTable>` | Creates consistency when JOINing and deleting data. |
| **Indexes** | `IX_<TableName>_<ColumnName>`<br/> Unique: `UX_<TableName>_<ColumnName>` | Easy to manage within Index Fragmentation systems. |
| **Unique Keys** | Constraint: `UQ_<TableName>_<ColumnName>` | Clearly distinguished from Indexes. |
| **Boolean Columns** | SQL Server: `BIT`<br/> Postgres: `BOOLEAN` | Never store booleans as `int` or `varchar('Y', 'N')`. |
| **Status Columns** | `TINYINT` / `SMALLINT` | Should map with Enums in C# code. Do not use Varchar for Statuses to save storage and speed up queries. |
| **Identity / UUID** | Use `UNIQUEIDENTIFIER` (`UUID`) for PK. Use `NEWSEQUENTIALID()` in SQL Server. | Microservices require UUIDs to generate independent distributed keys, preventing clashes during data merges or scaling. `NEWSEQUENTIALID()` mitigates Page Fragmentation in SQL Server. |
| **Audit Columns** | `CreatedDate`, `CreatedBy`, `UpdatedDate`, `UpdatedBy` | Mandatory for all crucial tables (Write Model) for tracking. |
| **Soft Delete** | `IsDeleted` (`BIT` / `BOOLEAN`) | Enterprises rarely hard-delete data due to tracing and legal compliance. |

---

## 7. Docker Environment

The local development environment uses Docker Compose.

### 7.1 Installation and Startup
Prerequisite: Docker Desktop is installed.

```bash
cd docker
docker-compose up -d
```

### 7.2 Docker Structure
- **Volume Mapping:** DB data is mapped externally (e.g., `./docker/data/sqlserver:/var/opt/mssql`) ensuring data persists when removing containers (`Persistent storage`).
- **Ports:**
  - SQL Server: `1433`
  - PostgreSQL: `5432`
- **Passwords & Network:** Managed via environment variables (`.env` file).
- **Database Initialization:** Scripts inside `docker/init-scripts/` run automatically once on new container creation, auto-creating roles, assigning permissions, and creating databases for domains.

### 7.3 Common Operations
- **Reset Environment (Wipe all data):** 
  `docker-compose down -v`
- **Upgrade DB version:** Change the image tag in the compose file and rerun.
- **Backup Local Volume:** Run a docker command mounting the volume to an alpine container to create a tar.gz file.

---

## 8. DBeaver Management

We selected **DBeaver** as our official tool because it boasts exceptional cross-platform support (SQL Server, PostgreSQL).

### 8.1 Project Configuration
1. Open DBeaver, select `File -> Open Project` -> point to the `.dbeaver` folder of this repo.
2. All dev connections (Local, Dev, Staging) are already pre-configured in the Project.

### 8.2 Team Sharing
- The `.dbeaver` folder is committed to Git (while files containing actual passwords are ignored via `.gitignore`).
- When a new Developer joins, they simply clone the repo, start Docker, open the DBeaver project, and all Connections will instantly appear, categorized by Folders (e.g., `Local/Account`, `Local/Product`).

> [!TIP]
> **Recommended Settings:** 
> Enable "Auto-commit = False" for Production/Staging environments in DBeaver to prevent accidental `UPDATE` statements without `WHERE` clauses.

---

## 9. Development Workflow

Are you a new Developer? Here is your day-to-day routine:

1. **Clone Repository:** `git clone <repo_url>`
2. **Start Docker:** `cd docker && docker-compose up -d`
3. **Open DBeaver:** Connect and verify the blank Databases.
4. **Run Migrations:** Run the CLI command to apply the latest migrations to your local DBs (e.g., using Flyway CLI or DbUp).
5. **Add New Tables/Columns:**
   - DO NOT edit old migration files.
   - Create a new SQL file (e.g., `V042__Add_Address_To_User.sql`).
   - Test run the migration on your local DB.
6. **Create a Pull Request (PR):** Push your feature branch to Git.
7. **Code Review & CI:** The CI pipeline will automatically run a dry-run of the SQL. A Senior DBA/Architect will review your PR.
8. **Merge:** Merge the feature branch into `main`.
9. **Release/Deployment:** The CD system will automatically fetch the latest SQL files and run them on Staging -> Production.

---

## 10. Git Workflow

- **Branch Naming:** `feature/<domain>/<task_id>` (e.g., `feature/account/JIRA-1234`)
- **Commit Naming:** Indexed with JIRA/Task ID. e.g., `[JIRA-1234] Add User Address table`.
- **Merge Strategy:** Squash & Merge (keeps git history clean).
- **SQL Review Checklist:** 
  - [ ] Will the migration create a Table Lock for too long?
  - [ ] Are Indexes missing for a new Foreign Key?
  - [ ] Are new columns nullable (if added to tables with millions of rows)?

---

## 11. Backup & Restore

### SQL Server
- **Backup:** Use weekly Full Backups and Differential/Log Backups every 15 minutes pushed to Azure Blob/S3 via Maintenance Plans.
- **Restore:** Directly use SSMS or the command `RESTORE DATABASE ... FROM DISK ... WITH RECOVERY`.

### PostgreSQL
- **Backup:** Use `pg_dump` for Logical Backups and tools like `WAL-G` / `Barman` for Point-In-Time-Recovery (PITR).
- **Restore:** Use `pg_restore` for dump files.

### Dev Environment (Disaster Recovery):
Completely delete Docker containers and volumes, then rerun migrations from V1 to the present.

---

## 12. Troubleshooting

| Common Issue | Cause | Solution |
|---|---|---|
| **Docker won't start** | Ports 1433 or 5432 are occupied. | Stop local SQL Server or Postgres services. Use `netstat -ano` to find PIDs. |
| **Migration conflicts** | 2 branches concurrently created a V012 migration. | The later merged PR must manually rename their file to V013. |
| **Database already exists** | Init script ran twice. | Ignore or write scripts utilizing `IF NOT EXISTS CREATE...` |
| **Permission denied (Postgres)** | Table created but read user lacks permissions. | Always grant permissions: `GRANT SELECT ON ALL TABLES IN SCHEMA public TO <ReadUser>;` |
| **Corrupted migration** | A buggy SQL was written but the file was saved in the migration tool's history. | In dev: Fix the file, delete the tool's tracking table record, and rerun. In Prod: Write a new migration file to `DROP` and recreate it. |

---

## 13. Frequently Asked Questions (FAQ)

**Q: Why use both SQL Server and Postgres? Why not just one?**
A: SQL Server Enterprise licenses are very expensive, it is optimized for the central transactional engine (Write). Postgres is free and its read scaling capabilities (Read Replicas) are immensely powerful, saving tremendous costs.

**Q: What if I need to join the User table and the Product table?**
A: Direct JOINs in SQL are forbidden. Returns will be handled by the Backend; the Backend will fetch Data from the 2 Read Models via 2 queries and map it in-memory, or construct a Materialized view via Message Brokers for the Read Model.

**Q: How do I know when data changes on the Write DB have reached the Read DB?**
A: We use Eventual Consistency (Outbox Pattern/Debezium/Kafka). Latency is extremely low (typically a few ms). If strict realtime data is required immediately after a Create, the Backend should temporarily read from the Write DB using the `Id`.

---

## 14. Best Practices

1. **Understand Data Lifecycles:** Do not rush to create columns. Ask yourself, "Will this column be updated frequently?". If so, should it be split into a separate table to avoid locks (Lock Contention) on the main table?
2. **Foreign Keys and Indexes:** EVERY Foreign Key MUST have an accompanying Index. Otherwise, when deleting a row in a parent table, the entire child table undergoes a Table Scan.
3. **Schema Updates (Large Tables):** When adding columns to tables with tens of millions of rows, do not instantly create columns with a `DEFAULT constraint`. Add a nullable column first, subsequently update it in small batches (batching), and only then set the `NOT NULL` constraint.
4. **Team Culture:** Discuss the Schema with an Architect / Database Admin before you start coding the feature. A good SQL Migration saves tens of hours of ORM debugging.

---
*Document compiled and maintained by the Enterprise Architecture Team.*
