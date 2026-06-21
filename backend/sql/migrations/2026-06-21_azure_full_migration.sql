-- ============================================================
-- AZURE FULL MIGRATION SCRIPT
-- Run this on Azure SQL Database (phongtro-db-2026)
-- Includes: ViewingAppointments + Rentals + Reviews upgrade
-- ============================================================

-- 1. CREATE ViewingAppointments table (if not exists)
IF OBJECT_ID(N'dbo.ViewingAppointments', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.ViewingAppointments
    (
        appointment_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ViewingAppointments PRIMARY KEY,
        listing_id     BIGINT NOT NULL,
        tenant_id      BIGINT NOT NULL,
        landlord_id    BIGINT NOT NULL,
        scheduled_at   DATETIME2 NOT NULL,
        status         VARCHAR(20) NOT NULL CONSTRAINT DF_ViewingAppointments_Status DEFAULT ('pending'),
        tenant_note    NVARCHAR(500) NULL,
        landlord_note  NVARCHAR(500) NULL,
        created_at     DATETIME2 NULL CONSTRAINT DF_ViewingAppointments_CreatedAt DEFAULT (GETDATE()),
        updated_at     DATETIME2 NULL CONSTRAINT DF_ViewingAppointments_UpdatedAt DEFAULT (GETDATE()),
        CONSTRAINT FK_ViewingAppointments_Listings  FOREIGN KEY (listing_id)  REFERENCES dbo.Listings(listing_id),
        CONSTRAINT FK_ViewingAppointments_Tenants   FOREIGN KEY (tenant_id)   REFERENCES dbo.Users(user_id),
        CONSTRAINT FK_ViewingAppointments_Landlords FOREIGN KEY (landlord_id) REFERENCES dbo.Users(user_id),
        CONSTRAINT CK_ViewingAppointments_Status    CHECK (status IN ('pending','confirmed','declined','cancelled')),
        CONSTRAINT CK_ViewingAppointments_NotSelf   CHECK (tenant_id <> landlord_id)
    );

    CREATE INDEX IX_ViewingAppointments_Tenant   ON dbo.ViewingAppointments(tenant_id,  scheduled_at);
    CREATE INDEX IX_ViewingAppointments_Landlord ON dbo.ViewingAppointments(landlord_id, scheduled_at);
    CREATE INDEX IX_ViewingAppointments_Listing  ON dbo.ViewingAppointments(listing_id);

    PRINT 'Created table: ViewingAppointments';
END
ELSE
    PRINT 'Table ViewingAppointments already exists - skipped.';

-- 2. CREATE Rentals table (if not exists)
IF OBJECT_ID(N'[dbo].[Rentals]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Rentals] (
        [rental_id]   BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [listing_id]  BIGINT NOT NULL,
        [tenant_id]   BIGINT NOT NULL,
        [landlord_id] BIGINT NOT NULL,
        [start_date]  DATETIME2 NOT NULL CONSTRAINT [DF_Rentals_start_date]  DEFAULT SYSUTCDATETIME(),
        [end_date]    DATETIME2 NULL,
        [status]      VARCHAR(20) NOT NULL CONSTRAINT [DF_Rentals_status]     DEFAULT 'active',
        [created_at]  DATETIME2 NOT NULL CONSTRAINT [DF_Rentals_created_at]  DEFAULT SYSUTCDATETIME(),
        [updated_at]  DATETIME2 NOT NULL CONSTRAINT [DF_Rentals_updated_at]  DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [FK_Rentals_Listings]  FOREIGN KEY ([listing_id])  REFERENCES [dbo].[Listings]([listing_id]),
        CONSTRAINT [FK_Rentals_Tenants]   FOREIGN KEY ([tenant_id])   REFERENCES [dbo].[Users]([user_id]),
        CONSTRAINT [FK_Rentals_Landlords] FOREIGN KEY ([landlord_id]) REFERENCES [dbo].[Users]([user_id]),
        CONSTRAINT [CK_Rentals_Status]    CHECK ([status] IN ('active','ended')),
        CONSTRAINT [CK_Rentals_NotSelf]   CHECK ([tenant_id] <> [landlord_id])
    );

    PRINT 'Created table: Rentals';
END
ELSE
    PRINT 'Table Rentals already exists - skipped.';

-- 3. UPGRADE Reviews table

-- 3a. Make rating NULLable
ALTER TABLE dbo.Reviews ALTER COLUMN rating TINYINT NULL;

-- 3b. Add 'type' column
IF COL_LENGTH('dbo.Reviews', 'type') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [type] VARCHAR(10) NOT NULL CONSTRAINT DF_Reviews_Type DEFAULT ('review');
    PRINT 'Added column Reviews.type';
END

-- 3c. Add 'status' column
IF COL_LENGTH('dbo.Reviews', 'status') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [status] VARCHAR(20) NOT NULL CONSTRAINT DF_Reviews_Status DEFAULT ('approved');
    PRINT 'Added column Reviews.status';
END

-- 3d. Add 'report_count' column
IF COL_LENGTH('dbo.Reviews', 'report_count') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [report_count] INT NOT NULL CONSTRAINT DF_Reviews_ReportCount DEFAULT (0);
    PRINT 'Added column Reviews.report_count';
END

-- 3e. Add 'is_deleted' column
IF COL_LENGTH('dbo.Reviews', 'is_deleted') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [is_deleted] BIT NOT NULL CONSTRAINT DF_Reviews_IsDeleted DEFAULT (0);
    PRINT 'Added column Reviews.is_deleted';
END

-- 3f. Drop old unique constraints on Reviews(listing_id, reviewer_id) - any auto-named ones
DECLARE @ConstraintName NVARCHAR(255);
SELECT TOP 1 @ConstraintName = kc.name
FROM sys.key_constraints kc
INNER JOIN sys.tables tb ON tb.object_id = kc.parent_object_id
WHERE tb.name = 'Reviews' AND kc.type = 'UQ';

IF @ConstraintName IS NOT NULL
BEGIN
    DECLARE @DropSql NVARCHAR(MAX) = 'ALTER TABLE dbo.Reviews DROP CONSTRAINT ' + QUOTENAME(@ConstraintName);
    EXEC sp_executesql @DropSql;
    PRINT 'Dropped old unique constraint on Reviews: ' + @ConstraintName;
END

-- Drop unique index if named explicitly
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ__Reviews__ED9BC2D526F2A52C' AND object_id = OBJECT_ID('dbo.Reviews'))
BEGIN
    DROP INDEX UQ__Reviews__ED9BC2D526F2A52C ON dbo.Reviews;
    PRINT 'Dropped old unique index on Reviews';
END

-- 3g. Create new filtered unique index: one review per tenant per listing
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UX_Reviews_Listing_Reviewer_Type' AND object_id = OBJECT_ID('dbo.Reviews'))
BEGIN
    CREATE UNIQUE INDEX UX_Reviews_Listing_Reviewer_Type
        ON dbo.Reviews(listing_id, reviewer_id)
        WHERE type = 'review' AND is_deleted = 0;
    PRINT 'Created index UX_Reviews_Listing_Reviewer_Type';
END

-- 4. ADD cached landlord reputation columns
IF COL_LENGTH('dbo.Users', 'reputation_score') IS NULL
BEGIN
    ALTER TABLE dbo.Users
        ADD reputation_score FLOAT NOT NULL
            CONSTRAINT DF_Users_ReputationScore DEFAULT (5.0);
    PRINT 'Added column Users.reputation_score';
END

IF COL_LENGTH('dbo.Users', 'reputation_count') IS NULL
BEGIN
    ALTER TABLE dbo.Users
        ADD reputation_count INT NOT NULL
            CONSTRAINT DF_Users_ReputationCount DEFAULT (0);
    PRINT 'Added column Users.reputation_count';
END

PRINT '=== Azure migration completed successfully ===';
