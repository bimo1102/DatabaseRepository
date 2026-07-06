# Tài Liệu Quản Trị & Phát Triển Cơ Sở Dữ Liệu (Database Repository)

> **Tài liệu chuẩn mực dành cho Kỹ sư Cơ sở dữ liệu, Kiến trúc sư & Lập trình viên**

Chào mừng bạn đến với kho lưu trữ cơ sở dữ liệu (Database Repository). Đây là nguồn chân lý duy nhất (Single Source of Truth) để quản lý, bảo trì và phát triển toàn bộ cơ sở dữ liệu của hệ thống. Tài liệu này được thiết kế theo các tiêu chuẩn doanh nghiệp khắt khe nhất (Enterprise-Grade) nhằm đảm bảo sự ổn định, khả năng mở rộng và hiệu suất tối đa.

---

## 📑 Mục Lục

1. [Kiến Trúc Tổng Quan (Architecture)](#1-kiến-trúc-tổng-quan-architecture)
2. [Thiết Kế Cơ Sở Dữ Liệu (Database Design)](#2-thiết-kế-cơ-sở-dữ-liệu-database-design)
3. [Cấu Trúc Thư Mục (Repository Structure)](#3-cấu-trúc-thư-mục-repository-structure)
4. [Chiến Lược Migration (SQL Migration Strategy)](#4-chiến-lược-migration-sql-migration-strategy)
5. [Ví Dụ Domain (Domain Example: Account)](#5-ví-dụ-domain-domain-example-account)
6. [Tiêu Chuẩn Thiết Kế (SQL Standards)](#6-tiêu-chuẩn-thiết-kế-sql-standards)
7. [Môi Trường Docker (Docker Environment)](#7-môi-trường-docker-docker-environment)
8. [Quản Trị Bằng DBeaver (DBeaver Management)](#8-quản-trị-bằng-dbeaver-dbeaver-management)
9. [Quy Trình Phát Triển (Development Workflow)](#9-quy-trình-phát-triển-development-workflow)
10. [Quy Trình Git (Git Workflow)](#10-quy-trình-git-git-workflow)
11. [Sao Lưu & Phục Hồi (Backup & Restore)](#11-sao-lưu--phục-hồi-backup--restore)
12. [Xử Lý Sự Cố (Troubleshooting)](#12-xử-lý-sự-cố-troubleshooting)
13. [Câu Hỏi Thường Gặp (FAQ)](#13-câu-hỏi-thường-gặp-faq)
14. [Thực Hành Tốt Nhất (Best Practices)](#14-thực-hành-tốt-nhất-best-practices)

---

## 1. Kiến Trúc Tổng Quan (Architecture)

Hệ thống của chúng ta được thiết kế dựa trên mô hình **CQRS (Command Query Responsibility Segregation)** kết hợp với **Domain-Driven Design (DDD)**. 

### Công Nghệ Sử Dụng:
- **Write Database (Command):** SQL Server
- **Read Database (Query):** PostgreSQL
- **Công cụ quản lý:** DBeaver
- **Triển khai môi trường dev:** Docker & Docker Compose

> [!IMPORTANT]
> **KHÔNG SỬ DỤNG ENTITY FRAMEWORK (EF)** để tạo hoặc migrate cơ sở dữ liệu. 
> **KHÔNG SỬ DỤNG EF MIGRATIONS**.
> Mọi thay đổi schema đều phải được thực hiện bằng file SQL Migration thuần túy.

### Tại Sao Lại Chọn Kiến Trúc Này?
1. **Phân Tách Trách Nhiệm Rõ Ràng (CQRS):** Việc tách biệt hệ thống ghi (Write - tối ưu cho transaction, ACID) và hệ thống đọc (Read - tối ưu cho tốc độ truy vấn, flat data) giúp hệ thống dễ dàng scale độc lập. SQL Server xử lý transaction cực kỳ tốt nhờ khả năng lock management, trong khi PostgreSQL có khả năng xử lý JSONB và index mạnh mẽ, rất phù hợp cho Read Model.
2. **Kiểm Soát Hoàn Toàn (No ORM Migrations):** EF Migrations sinh ra các câu lệnh SQL tự động không tối ưu và ẩn giấu rủi ro khóa bảng (table lock) ở môi trường production. Quản lý bằng SQL thuần giúp DBA và Developer kiểm soát 100% cách thức dữ liệu thay đổi, tối ưu index và transaction.
3. **Tính Độc Lập Giữa Các Domain (DDD):** Mỗi domain là một ốc đảo riêng biệt, ngăn chặn hoàn toàn "Spaghetti Database".

---

## 2. Thiết Kế Cơ Sở Dữ Liệu (Database Design)

Mỗi Business Domain sở hữu cơ sở dữ liệu độc lập của riêng nó.

Ví dụ các domains: `Account`, `Product`, `Purchase`, `Sender`, `Medical`, `General`, `Notification`, v.v.

Mỗi Domain sẽ có 2 databases vật lý (hoặc logical tùy môi trường):
- `<Domain>_Write` (SQL Server)
- `<Domain>_Read` (PostgreSQL)

### Quy Tắc Thiết Kế Cốt Lõi:
> [!CAUTION]
> - **Độc Lập Hoàn Toàn:** Không có bảng nào chia sẻ giữa các domain.
> - **Không Khóa Ngoại Xuyên Domain:** Các domain giao tiếp với nhau bằng Event/Message Broker hoặc API, tuyệt đối không tạo Foreign Key nối bảng của Domain Account sang Domain Product.
> - **Nguyên Tắc Eventual Consistency:** Dữ liệu từ Write DB sẽ được đồng bộ sang Read DB thông qua Event Worker.

---

## 3. Cấu Trúc Thư Mục (Repository Structure)

Cấu trúc thư mục được thiết kế để dễ dàng mở rộng và quản lý version.

```text
DatabaseRepository/
├── .dbeaver/                  # Cấu hình project cho DBeaver
├── docker/                    # File cấu hình Docker
│   ├── docker-compose.yml
│   └── init-scripts/          # Shell scripts để init database khi start docker
├── domains/                   # Chứa tất cả domains
│   ├── Account/               
│   │   ├── Write_SQLServer/   # Migration cho Write DB của Account
│   │   │   ├── migrations/    # Các file SQL thay đổi schema
│   │   │   └── seeds/         # Dữ liệu mẫu (master data)
│   │   └── Read_PostgreSQL/   # Migration cho Read DB của Account
│   │       ├── migrations/
│   │       └── seeds/
│   ├── Product/               # Cấu trúc tương tự Account
│   └── ...
├── docs/                      # Tài liệu chi tiết, ERD, Data dictionary
└── README.md                  # Tài liệu này
```

---

## 4. Chiến Lược Migration (SQL Migration Strategy)

Chúng ta sử dụng chiến lược **Immutable Migrations (Migration Bất Biến)**.

### Nguyên Tắc Bất Di Bất Dịch:
> [!WARNING]
> **MỘT KHI MIGRATION ĐÃ ĐƯỢC MERGE VÀO NHÁNH `main`, TUYỆT ĐỐI KHÔNG ĐƯỢC SỬA ĐỔI FILE ĐÓ.**

**Lý do:** Khi một file được chạy ở Production, schema đã thay đổi. Nếu bạn sửa file cũ, tool chạy migration sẽ không biết để chạy lại (hoặc sẽ báo lỗi checksum mismatch). Mọi thay đổi (thêm cột, sửa kiểu dữ liệu) **BẮT BUỘC** phải được thực hiện bằng cách tạo một file migration mới.

### Quy Ước Đặt Tên Migration:
Định dạng: `V<Version>__<Mô_tả>.sql` (Ví dụ dùng Flyway naming convention).

**Ví dụ đúng:**
- `V001__Create_User_Table.sql`
- `V002__Add_Email_Column.sql`
- `V003__Add_Index_Email.sql`

**Ví dụ sai (Tuyệt đối cấm):**
- Mở file `V001__Create_User_Table.sql` và thêm cột `Email`.

---

## 5. Ví Dụ Domain (Domain Example: Account)

Domain `Account` quản lý danh tính người dùng.

### 5.1 Write Model (SQL Server)
Write model được chuẩn hóa (3NF) để đảm bảo tính toàn vẹn dữ liệu và ACID.

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
    [RowVersion] ROWVERSION NOT NULL, -- Cho Optimistic Concurrency
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

**Giải thích Write Model:**
- **Users**: Lưu thông tin cốt lõi dùng để đăng nhập và bảo mật.
- **UserInformations**: Lưu thông tin chi tiết, có thể cập nhật thường xuyên mà không ảnh hưởng tới lock của bảng Users. 
- **RowVersion**: Dùng để xử lý Optimistic Concurrency (tránh mất dữ liệu khi 2 người cùng update).

### 5.2 Read Model (PostgreSQL)
Read model được khử chuẩn hóa (Denormalized) nhằm tối ưu hóa số lượng JOIN và cung cấp dữ liệu ngay lập tức cho các API Read.

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
CREATE INDEX idx_users_read_fullname_trgm ON users_read USING GIN (full_name gin_trgm_ops); -- Phục vụ full-text search
```

**Giải thích Read Model:**
- Gộp chung `User` và `UserInformation` thành một bảng phẳng (flat table) `users_read`. Khi gọi API lấy thông tin Account, chỉ cần `SELECT *` không cần `JOIN`.
- Không có cột `Password`, `PasswordSalt`, hay `RowVersion` vì Read Model không phục vụ đăng nhập hay xử lý transaction.
- Hỗ trợ Index GIN cho tính năng tìm kiếm văn bản tốc độ cao.

---

## 6. Tiêu Chuẩn Thiết Kế (SQL Standards)

Hệ thống yêu cầu các quy ước nghiêm ngặt để đảm bảo tính nhất quán.

| Yếu Tố | Quy Ước (Convention) | Giải Thích & Lý Do (Why) |
|---|---|---|
| **Database Naming** | `PascalCase` (VD: `Account_Write`, `Product_Read`) | Dễ nhận diện, đồng bộ với tên Domain trong code C#. |
| **Schema Naming** | SQL Server: `dbo`. Postgres: `public` hoặc theo context | Giữ chuẩn mặc định để giảm bớt độ phức tạp khi phân quyền. |
| **Table Naming** | `PascalCase`, số nhiều (VD: `Users`, `Products`) <br/> Postgres: `snake_case`, số nhiều (VD: `users_read`) | SQL Server truyền thống dùng PascalCase. Postgres luôn dùng lowercase + snake_case để tránh lỗi phân biệt hoa/thường khó chịu khi query. |
| **Column Naming** | SQL Server: `PascalCase`<br/>Postgres: `snake_case` | Đồng bộ với Table Naming. |
| **Primary Keys** | Cột `Id`. Ràng buộc: `PK_<TableName>` | Dễ dàng map với BaseDomain `Id`. Tên ràng buộc rõ ràng để dễ debug. |
| **Foreign Keys** | Tên cột: `<TableName>Id` (VD: `UserId`).<br/> Ràng buộc: `FK_<Table>_<RefTable>` | Tạo tính nhất quán khi cần JOIN và khi xóa data. |
| **Indexes** | `IX_<TableName>_<ColumnName>`<br/> Unique: `UX_<TableName>_<ColumnName>` | Dễ quản lý trong hệ thống Index Fragmentation. |
| **Unique Keys** | Ràng buộc: `UQ_<TableName>_<ColumnName>` | Phân biệt rõ ràng với Index. |
| **Boolean Columns** | SQL Server: `BIT`<br/> Postgres: `BOOLEAN` | Đừng bao giờ lưu boolean bằng `int` hoặc `varchar('Y', 'N')`. |
| **Status Columns** | `TINYINT` / `SMALLINT` | Nên map với Enum trong code C#. Không dùng Varchar cho Status để tiết kiệm dung lượng và tăng tốc query. |
| **Identity / UUID** | Dùng `UNIQUEIDENTIFIER` (`UUID`) làm PK. Dùng `NEWSEQUENTIALID()` ở SQL Server. | Microservices cần UUID để gen key phân tán độc lập, tránh đụng độ khi merge data hoặc scale. `NEWSEQUENTIALID()` giúp chống phân mảnh trang dữ liệu (Page Fragmentation) ở SQL Server. |
| **Audit Columns** | `CreatedDate`, `CreatedBy`, `UpdatedDate`, `UpdatedBy` | Bắt buộc cho mọi bảng quan trọng (Write Model) để track vết. |
| **Soft Delete** | `IsDeleted` (`BIT` / `BOOLEAN`) | Doanh nghiệp hiếm khi xóa cứng dữ liệu để phục vụ truy vết và pháp lý. |

---

## 7. Môi Trường Docker (Docker Environment)

Môi trường phát triển cục bộ (Local) sử dụng Docker Compose. 

### 7.1 Cài Đặt và Khởi Chạy
Yêu cầu: Đã cài Docker Desktop.

```bash
cd docker
docker-compose up -d
```

### 7.2 Cấu Trúc Docker
- **Volume Mapping:** Dữ liệu DB được map ra ngoài (VD: `./docker/data/sqlserver:/var/opt/mssql`) để đảm bảo không mất data khi xóa container (`Persistent storage`).
- **Ports:**
  - SQL Server: `1433`
  - PostgreSQL: `5432`
- **Mật khẩu & Network:** Quản lý qua biến môi trường (File `.env`).
- **Khởi tạo (Database initialization):** Các script trong `docker/init-scripts/` tự động chạy 1 lần khi container tạo mới, giúp tự động tạo role, phân quyền và tạo database cho các domain.

### 7.3 Thao Tác Thường Dùng
- **Reset môi trường (Xóa sạch data):** 
  `docker-compose down -v`
- **Nâng cấp version DB:** Đổi image tag trong file compose và chạy lại.
- **Backup Volume Local:** Dùng lệnh docker run mount volume vào alpine container tạo file tar.gz.

---

## 8. Quản Trị Bằng DBeaver (DBeaver Management)

Chúng tôi chọn **DBeaver** làm công cụ chính thức vì nó hỗ trợ đa nền tảng (SQL Server, PostgreSQL) rất tốt.

### 8.1 Cấu Hình Project
1. Mở DBeaver, chọn `File -> Open Project` -> trỏ vào thư mục `.dbeaver` của repo này.
2. Mọi kết nối dev (Local, Dev, Staging) đã được thiết lập sẵn trong Project.

### 8.2 Team Sharing
- Folder `.dbeaver` được commit lên Git (nhưng bỏ qua file chứa mật khẩu thực tế qua `.gitignore`). 
- Khi có một Developer mới gia nhập, họ chỉ cần clone repo, bật Docker, mở project DBeaver và mọi Connection đều hiện sẵn, chia theo Folder (VD: `Local/Account`, `Local/Product`).

> [!TIP]
> **Recommended Settings:** 
> Bật chế độ "Auto-commit = False" cho môi trường Production/Staging trên DBeaver để ngăn chặn vô tình `UPDATE` quên `WHERE`.

---

## 9. Quy Trình Phát Triển (Development Workflow)

Bạn là Developer mới? Đây là công việc hằng ngày của bạn:

1. **Clone Repository:** `git clone <repo_url>`
2. **Start Docker:** `cd docker && docker-compose up -d`
3. **Mở DBeaver:** Kết nối và kiểm tra Database trắng.
4. **Chạy Migration:** Chạy lệnh CLI để apply migration mới nhất vào DB local của bạn (Ví dụ dùng Flyway CLI hoặc DbUp).
5. **Thêm Bảng/Cột Mới:** 
   - KHÔNG sửa file migration cũ.
   - Tạo file SQL mới (VD: `V042__Add_Address_To_User.sql`).
   - Chạy thử migration ở DB local.
6. **Tạo Pull Request (PR):** Đẩy nhánh tính năng lên Git.
7. **Code Review & CI:** CI pipeline sẽ tự động chạy dry-run SQL. Senior DBA/Architect duyệt PR.
8. **Merge:** Nhánh tính năng vào `main`.
9. **Release/Deployment:** Hệ thống CD sẽ tự động lấy file SQL mới nhất và chạy trên Staging -> Production.

---

## 10. Quy Trình Git (Git Workflow)

- **Branch Naming:** `feature/<domain>/<task_id>` (VD: `feature/account/JIRA-1234`)
- **Commit Naming:** Lập chỉ mục với JIRA/Task ID. VD: `[JIRA-1234] Add User Address table`.
- **Merge Strategy:** Squash & Merge (giúp lịch sử git sạch sẽ).
- **SQL Review Checklist:** 
  - [ ] Migration có tạo Lock Table quá lâu không?
  - [ ] Có thiếu Index cho Foreign Key mới không?
  - [ ] Cột mới có nullable không (nếu thêm vào bảng có sẵn triệu dòng)?

---

## 11. Sao Lưu & Phục Hồi (Backup & Restore)

### SQL Server
- **Backup:** Sử dụng Full Backup hằng tuần và Differential/Log Backup mỗi 15 phút vào Azure Blob/S3 bằng Maintenance Plan.
- **Restore:** Trực tiếp dùng SSMS hoặc lệnh `RESTORE DATABASE ... FROM DISK ... WITH RECOVERY`.

### PostgreSQL
- **Backup:** Sử dụng `pg_dump` cho Logical Backup và công cụ như `WAL-G` / `Barman` cho Point-In-Time-Recovery (PITR).
- **Restore:** Dùng `pg_restore` cho file dump.

### Môi trường Dev (Disaster Recovery):
Xóa hoàn toàn docker container và volumes, sau đó chạy lại migration từ V1 đến hiện tại.

---

## 12. Xử Lý Sự Cố (Troubleshooting)

| Lỗi Thường Gặp | Nguyên Nhân | Cách Khắc Phục |
|---|---|---|
| **Docker won't start** | Cổng 1433 hoặc 5432 bị chiếm dụng. | Tắt local service SQL Server hoặc Postgres. Dùng `netstat -ano` để tìm PID. |
| **Migration conflicts** | 2 nhánh cùng tạo migration có version V012. | PR merge sau phải tự đổi tên file thành V013. |
| **Database already exists** | Init script chạy 2 lần. | Bỏ qua hoặc viết script `IF NOT EXISTS CREATE...` |
| **Permission denied (Postgres)** | Tạo bảng nhưng user đọc không có quyền. | Luôn cấp quyền: `GRANT SELECT ON ALL TABLES IN SCHEMA public TO <ReadUser>;` |
| **Corrupted migration** | Viết SQL bị lỗi nhưng file đã được lưu trong lịch sử tool migration. | Ở dev: Fix file, xóa bảng track của tool, chạy lại. Ở Prod: Viết file migration mới để `DROP` và tạo lại. |

---

## 13. Câu Hỏi Thường Gặp (FAQ)

**Q: Tại sao phải dùng cả SQL Server và Postgres? Tại sao không dùng 1 loại?**
A: SQL Server bản Enterprise chi phí license rất cao, tối ưu dùng làm bộ máy giao dịch trung tâm (Write). Postgres miễn phí, khả năng scale đọc (Read Replica) rất mạnh mẽ, tiết kiệm chi phí cực lớn.

**Q: Nếu em cần join bảng User và bảng Product thì sao?**
A: Không được phép Join trực tiếp trong SQL. Trả về phía Backend, Backend sẽ fetch Data từ 2 Read Model bằng 2 query rồi map in-memory, hoặc xây dựng 1 view Materialized thông qua Message Broker cho Read Model.

**Q: Làm sao em biết dữ liệu thay đổi trên Write DB đã sang Read DB?**
A: Chúng ta dùng Eventual Consistency (Outbox Pattern/Debezium/Kafka). Nó có độ trễ nhỏ (thường vài ms). Nếu cần dữ liệu realtime ngặt nghèo ngay sau lúc Create, Backend nên đọc tạm từ Write DB bằng `Id`.

---

## 14. Thực Hành Tốt Nhất (Best Practices)

1. **Hiểu Đời Sống Dữ Liệu:** Đừng vội tạo cột. Hãy tự hỏi "Cột này update thường xuyên không?". Nếu có, có nên tách ra bảng riêng để tránh khóa (Lock Contention) bảng chính?
2. **Khóa Ngoại và Index:** MỌI Khóa Ngoại (Foreign Key) ĐỀU PHẢI có Index đi kèm. Nếu không, khi xóa dòng ở bảng cha, toàn bộ bảng con sẽ bị Table Scan.
3. **Cập Nhật Schema (Large Tables):** Khi thêm cột cho bảng có hàng chục triệu dòng, không tạo cột với `DEFAULT constraint` ngay. Hãy thêm cột nullable trước, sau đó update từng batch nhỏ (batching), rồi mới set constraint `NOT NULL`.
4. **Văn hóa Team:** Hãy thảo luận Schema với Architect / Database Admin trước khi bắt đầu code tính năng. SQL Migration tốt tiết kiệm hàng chục giờ debug ORM.

---
*Tài liệu được biên soạn và bảo trì bởi Enterprise Architecture Team.*
