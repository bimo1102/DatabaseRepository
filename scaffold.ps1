$ErrorActionPreference = 'Stop'

$domains = @("account", "product", "purchase", "medical", "general", "sender", "notification")

# 1. Remove deprecated migrations root
if (Test-Path "migrations") {
    Remove-Item "migrations" -Recurse -Force
}

# 2. Create core directories
$coreDirs = @(
    "docker/sqlserver", 
    "docker/postgres", 
    "scripts", 
    ".dbeaver/Connections", 
    ".dbeaver/Scripts",
    "docs",
    ".github/workflows",
    "databases/templates/migrations",
    "databases/templates/seed"
)
foreach ($dir in $coreDirs) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

# 3. Create domain templates
foreach ($domain in $domains) {
    $paths = @(
        "databases/$domain/sqlserver/migrations",
        "databases/$domain/sqlserver/seed",
        "databases/$domain/sqlserver/procedures",
        "databases/$domain/sqlserver/functions",
        "databases/$domain/sqlserver/triggers",
        "databases/$domain/postgres/migrations",
        "databases/$domain/postgres/seed",
        "databases/$domain/postgres/views",
        "databases/$domain/postgres/functions",
        "databases/$domain/postgres/triggers"
    )
    foreach ($path in $paths) {
        New-Item -ItemType Directory -Force -Path $path | Out-Null
    }
}

# 4. Create Account Reference Implementation SQL
Set-Content -Path "databases/account/sqlserver/migrations/001_Create_User.sql" -Value "-- Write Model: Users`nCREATE TABLE dbo.Users (`n  Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),`n  UserName NVARCHAR(256) NOT NULL,`n  Email NVARCHAR(256)`n);"
Set-Content -Path "databases/account/sqlserver/migrations/002_Create_UserInformation.sql" -Value "-- Write Model: UserInformation`nCREATE TABLE dbo.UserInformation (`n  Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWSEQUENTIALID(),`n  UserId UNIQUEIDENTIFIER NOT NULL,`n  FullName NVARCHAR(256)`n);"
Set-Content -Path "databases/account/sqlserver/migrations/003_Create_Index.sql" -Value "-- Index for User email`nCREATE NONCLUSTERED INDEX IX_Users_Email ON dbo.Users(Email);"
Set-Content -Path "databases/account/sqlserver/seed/004_Seed_Admin.sql" -Value "-- Master Data Seed`nINSERT INTO dbo.Users (UserName) VALUES ('Admin');"

Set-Content -Path "databases/account/postgres/migrations/001_Create_User.sql" -Value "-- Read Model: Denormalized User Table`nCREATE TABLE public.users_read (`n  id UUID PRIMARY KEY,`n  username VARCHAR(256) NOT NULL,`n  email VARCHAR(256)`n);"
Set-Content -Path "databases/account/postgres/migrations/002_Create_UserInformation.sql" -Value "-- Read Model: Adding full name to users_read flat table`nALTER TABLE public.users_read ADD COLUMN full_name VARCHAR(256);"

# 5. Create Templates
Set-Content -Path "databases/templates/migrations/000_Template.sql" -Value "-- Migration Template`n-- File Name Format: <VersionNumber>_<Description>.sql`n-- Example: 005_Add_Status_Column.sql`n-- Note: Migrations are immutable. NEVER edit a merged migration file.`n`nBEGIN TRANSACTION;`n  -- Your SQL here`nCOMMIT;"
Set-Content -Path "databases/templates/seed/000_Seed_Template.sql" -Value "-- Seed Template`n-- ONLY for master/reference data (e.g., Country List, Status Types).`n-- NEVER seed transactional or test data in production.`n"

# 6. Create Configuration Files
Set-Content -Path ".gitignore" -Value ".env`n.DS_Store`n.dbeaver/credentials-config.json`n"
Set-Content -Path ".editorconfig" -Value "root = true`n`n[*]`nindent_style = space`nindent_size = 4`nend_of_line = lf`ncharset = utf-8`ntrim_trailing_whitespace = true`ninsert_final_newline = true`n"
Set-Content -Path ".env.example" -Value "SQLSERVER_SA_PASSWORD=YourStrong@Passw0rd!`nPOSTGRES_PASSWORD=postgres`nPOSTGRES_USER=postgres`n"
Set-Content -Path "azure-pipelines.yml" -Value "# Azure Pipelines CI/CD Template`n"
Set-Content -Path ".github/workflows/ci.yml" -Value "# GitHub Actions CI Template`n"

# 7. Create Docker Setup Files
Set-Content -Path "docker/docker-compose.yml" -Value "version: '3.8'`nservices:`n  sqlserver:`n    image: mcr.microsoft.com/mssql/server:2022-latest`n  postgres:`n    image: postgres:15-alpine`n"
Set-Content -Path "docker/sqlserver/init.sql" -Value "-- SQL Server Init Script"
Set-Content -Path "docker/postgres/init.sql" -Value "-- Postgres Init Script"

# 8. Create Scripts Placeholders
Set-Content -Path "scripts/MigrationRunner.ps1" -Value "# PowerShell script to run Flyway or DbUp for all domains"
Set-Content -Path "scripts/SeedRunner.ps1" -Value "# PowerShell script to insert seed data"
Set-Content -Path "scripts/setup-local.sh" -Value "#!/bin/bash`n# Bash script for local environment bootstrapping"

# 9. Create Documentation Placeholders
Set-Content -Path "docs/architecture.md" -Value "# Architecture`n## CQRS & DDD Overview"
Set-Content -Path "docs/migration.md" -Value "# Migration Guidelines`n## Naming, versioning, rollback strategy"
Set-Content -Path "docs/docker.md" -Value "# Docker Setup`n## Local Dev Guidelines"
Set-Content -Path "docs/convention.md" -Value "# Database Conventions`n## Naming standards for tables, columns, indexes"
Set-Content -Path "docs/backup.md" -Value "# Backup and Restore`n## DR Procedures"
Set-Content -Path "docs/release.md" -Value "# Release Management`n## Deployment strategy"

# 10. Create DBeaver Placeholders
Set-Content -Path ".dbeaver/project-settings.json" -Value "{}"
Set-Content -Path ".dbeaver/Connections/Local.xml" -Value "<!-- DBeaver Connection config -->"
Set-Content -Path ".dbeaver/Scripts/README.md" -Value "# DBeaver Scratch Scripts"

Write-Output "Scaffolding completed successfully."
