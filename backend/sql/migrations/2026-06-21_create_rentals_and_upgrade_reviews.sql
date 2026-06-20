-- Migration: Create Rentals table and upgrade Reviews table for Verified Reviews & Q&A
-- Date: 2026-06-21

-- 1. Create Rentals table
IF OBJECT_ID(N'[dbo].[Rentals]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[Rentals] (
        [rental_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [listing_id] BIGINT NOT NULL,
        [tenant_id] BIGINT NOT NULL,
        [landlord_id] BIGINT NOT NULL,
        [start_date] DATETIME2 NOT NULL CONSTRAINT [DF_Rentals_start_date] DEFAULT SYSUTCDATETIME(),
        [end_date] DATETIME2 NULL,
        [status] VARCHAR(20) NOT NULL CONSTRAINT [DF_Rentals_status] DEFAULT 'active',
        [created_at] DATETIME2 NOT NULL CONSTRAINT [DF_Rentals_created_at] DEFAULT SYSUTCDATETIME(),
        [updated_at] DATETIME2 NOT NULL CONSTRAINT [DF_Rentals_updated_at] DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [FK_Rentals_Listings] FOREIGN KEY ([listing_id]) REFERENCES [dbo].[Listings]([listing_id]),
        CONSTRAINT [FK_Rentals_Tenants] FOREIGN KEY ([tenant_id]) REFERENCES [dbo].[Users]([user_id]),
        CONSTRAINT [FK_Rentals_Landlords] FOREIGN KEY ([landlord_id]) REFERENCES [dbo].[Users]([user_id]),
        CONSTRAINT [CK_Rentals_Status] CHECK ([status] IN ('active', 'ended')),
        CONSTRAINT [CK_Rentals_NotSelf] CHECK ([tenant_id] <> [landlord_id])
    );
END

-- 2. Upgrade Reviews table
-- Make rating NULLable (Q&A does not require a rating)
ALTER TABLE dbo.Reviews ALTER COLUMN rating TINYINT NULL;

-- Add 'type' column: 'qna' or 'review'
IF COL_LENGTH('dbo.Reviews', 'type') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [type] VARCHAR(10) NOT NULL CONSTRAINT DF_Reviews_Type DEFAULT ('review');
END

-- Add 'status' column: 'approved', 'pending', 'hidden'
IF COL_LENGTH('dbo.Reviews', 'status') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [status] VARCHAR(20) NOT NULL CONSTRAINT DF_Reviews_Status DEFAULT ('approved');
END

-- Add 'report_count' column
IF COL_LENGTH('dbo.Reviews', 'report_count') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [report_count] INT NOT NULL CONSTRAINT DF_Reviews_ReportCount DEFAULT (0);
END

-- Add 'is_deleted' column
IF COL_LENGTH('dbo.Reviews', 'is_deleted') IS NULL
BEGIN
    ALTER TABLE dbo.Reviews ADD [is_deleted] BIT NOT NULL CONSTRAINT DF_Reviews_IsDeleted DEFAULT (0);
END

-- 3. Drop the old unique constraint/index on Reviews(listing_id, reviewer_id) if exists
-- Drop unique constraint if exists
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'UQ__Reviews__ED9BC2D526F2A52C' AND type = 'UQ')
BEGIN
    ALTER TABLE dbo.Reviews DROP CONSTRAINT UQ__Reviews__ED9BC2D526F2A52C;
END

-- Drop unique index if exists
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ__Reviews__ED9BC2D526F2A52C' AND object_id = OBJECT_ID('dbo.Reviews'))
BEGIN
    DROP INDEX UQ__Reviews__ED9BC2D526F2A52C ON dbo.Reviews;
END

-- Drop foreign key constraint or index that might block Q&A if it has a random auto-generated constraint name
DECLARE @ConstraintName NVARCHAR(255);
SELECT @ConstraintName = dc.name
FROM sys.key_constraints dc
INNER JOIN sys.tables tb ON tb.object_id = dc.parent_object_id
WHERE tb.name = 'Reviews' AND dc.type = 'UQ';

IF @ConstraintName IS NOT NULL
BEGIN
    DECLARE @DropSql NVARCHAR(MAX) = 'ALTER TABLE dbo.Reviews DROP CONSTRAINT ' + QUOTENAME(@ConstraintName);
    EXEC sp_executesql @DropSql;
END

-- 4. Create Unique Filtered Index on Reviews (One Review per Tenant per Listing)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UX_Reviews_Listing_Reviewer_Type' AND object_id = OBJECT_ID('dbo.Reviews'))
BEGIN
    CREATE UNIQUE INDEX UX_Reviews_Listing_Reviewer_Type
    ON dbo.Reviews(listing_id, reviewer_id)
    WHERE type = 'review' AND is_deleted = 0;
END
