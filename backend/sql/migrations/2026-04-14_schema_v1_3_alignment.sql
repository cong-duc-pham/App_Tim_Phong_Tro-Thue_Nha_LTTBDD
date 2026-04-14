-- ============================================================
-- PHONGTRO DB - One-time migration alignment to schema v1.3
-- Date: 2026-04-14
-- Purpose:
--   1) Align Users.firebase_uid uniqueness for mixed local + Firebase auth
--   2) Ensure Listings cover-image check works with business status flow
--   3) Seed minimal master data for runtime safety
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT '--- Start v1.3 alignment migration ---';

BEGIN TRY
    BEGIN TRAN;

    -- ========================================================
    -- 1) USERS: firebase_uid unique only when NOT NULL
    -- ========================================================
    IF EXISTS (
        SELECT 1
        FROM sys.key_constraints
        WHERE [type] = 'UQ'
          AND [name] = 'UQ__Users__1E65B7F832289B9B'
          AND parent_object_id = OBJECT_ID('dbo.Users')
    )
    BEGIN
        PRINT 'Dropping legacy UQ__Users__1E65B7F832289B9B on dbo.Users(firebase_uid)...';
        ALTER TABLE dbo.Users DROP CONSTRAINT [UQ__Users__1E65B7F832289B9B];
    END

    IF NOT EXISTS (
        SELECT 1 FROM sys.indexes
        WHERE object_id = OBJECT_ID('dbo.Users')
          AND [name] = 'UX_Users_FirebaseUid_NotNull'
    )
    BEGIN
        PRINT 'Creating filtered unique index UX_Users_FirebaseUid_NotNull...';

        -- Required SET options for filtered indexes
        SET QUOTED_IDENTIFIER ON;
        SET ANSI_NULLS ON;
        SET ANSI_PADDING ON;
        SET ANSI_WARNINGS ON;
        SET ARITHABORT ON;
        SET CONCAT_NULL_YIELDS_NULL ON;
        SET NUMERIC_ROUNDABORT OFF;

        CREATE UNIQUE INDEX UX_Users_FirebaseUid_NotNull
            ON dbo.Users(firebase_uid)
            WHERE firebase_uid IS NOT NULL;
    END

    -- ========================================================
    -- 2) Ensure ListingStatus has required values
    -- ========================================================
    IF COLUMNPROPERTY(OBJECT_ID('dbo.ListingStatus'), 'status_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.ListingStatus ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.ListingStatus WHERE status_id = 1)
        INSERT INTO dbo.ListingStatus(status_id, status_name) VALUES (1, 'active');

    IF NOT EXISTS (SELECT 1 FROM dbo.ListingStatus WHERE status_id = 2)
        INSERT INTO dbo.ListingStatus(status_id, status_name) VALUES (2, 'pending');

    IF NOT EXISTS (SELECT 1 FROM dbo.ListingStatus WHERE status_id = 3)
        INSERT INTO dbo.ListingStatus(status_id, status_name) VALUES (3, 'rejected');

    IF NOT EXISTS (SELECT 1 FROM dbo.ListingStatus WHERE status_id = 4)
        INSERT INTO dbo.ListingStatus(status_id, status_name) VALUES (4, 'expired');

    IF NOT EXISTS (SELECT 1 FROM dbo.ListingStatus WHERE status_id = 5)
        INSERT INTO dbo.ListingStatus(status_id, status_name) VALUES (5, 'hidden');

    IF COLUMNPROPERTY(OBJECT_ID('dbo.ListingStatus'), 'status_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.ListingStatus OFF;

    -- ========================================================
    -- 3) Roles seed (minimum for register/auth)
    -- ========================================================
    IF COLUMNPROPERTY(OBJECT_ID('dbo.Roles'), 'role_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Roles ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE role_id = 1)
        INSERT INTO dbo.Roles(role_id, role_name, description, created_at)
        VALUES (1, N'admin', N'Quản trị hệ thống', SYSUTCDATETIME());

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE role_id = 2)
        INSERT INTO dbo.Roles(role_id, role_name, description, created_at)
        VALUES (2, N'tenant', N'Người thuê / người tìm trọ', SYSUTCDATETIME());

    IF NOT EXISTS (SELECT 1 FROM dbo.Roles WHERE role_id = 3)
        INSERT INTO dbo.Roles(role_id, role_name, description, created_at)
        VALUES (3, N'landlord', N'Chủ trọ / người đăng tin', SYSUTCDATETIME());

    IF COLUMNPROPERTY(OBJECT_ID('dbo.Roles'), 'role_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Roles OFF;

    -- ========================================================
    -- 4) Minimal master data for listing create in non-empty DB
    -- ========================================================
    IF COLUMNPROPERTY(OBJECT_ID('dbo.RoomTypes'), 'type_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.RoomTypes ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.RoomTypes WHERE type_id = 1)
        INSERT INTO dbo.RoomTypes(type_id, type_name, icon_url, sort_order, is_active)
        VALUES (1, N'Phòng trọ', NULL, 1, 1);

    IF COLUMNPROPERTY(OBJECT_ID('dbo.RoomTypes'), 'type_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.RoomTypes OFF;

    IF COLUMNPROPERTY(OBJECT_ID('dbo.Provinces'), 'province_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Provinces ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Provinces WHERE province_id = 1)
        INSERT INTO dbo.Provinces(province_id, province_name, province_code)
        VALUES (1, N'TP.HCM', 'HCM');

    IF COLUMNPROPERTY(OBJECT_ID('dbo.Provinces'), 'province_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Provinces OFF;

    IF COLUMNPROPERTY(OBJECT_ID('dbo.Districts'), 'district_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Districts ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Districts WHERE district_id = 1)
        INSERT INTO dbo.Districts(district_id, province_id, district_name, district_code)
        VALUES (1, 1, N'Quận 1', 'Q1');

    IF COLUMNPROPERTY(OBJECT_ID('dbo.Districts'), 'district_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Districts OFF;

    IF COLUMNPROPERTY(OBJECT_ID('dbo.Wards'), 'ward_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Wards ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Wards WHERE ward_id = 1)
        INSERT INTO dbo.Wards(ward_id, district_id, ward_name, ward_code)
        VALUES (1, 1, N'Phường Bến Nghé', 'BN');

    IF COLUMNPROPERTY(OBJECT_ID('dbo.Wards'), 'ward_id', 'IsIdentity') = 1
        SET IDENTITY_INSERT dbo.Wards OFF;

    -- ========================================================
    -- 5) CHECK constraint: cover image required only for active
    -- ========================================================
    IF EXISTS (
        SELECT 1
        FROM sys.check_constraints
        WHERE [name] = 'CK_cover_image_required'
          AND parent_object_id = OBJECT_ID('dbo.Listings')
    )
    BEGIN
        -- Recreate to ensure expected definition
        ALTER TABLE dbo.Listings DROP CONSTRAINT CK_cover_image_required;
    END

    ALTER TABLE dbo.Listings
        ADD CONSTRAINT CK_cover_image_required
        CHECK ([status_id] <> 1 OR [image_0] IS NOT NULL);

    COMMIT TRAN;
    PRINT '--- v1.3 alignment migration completed successfully ---';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRAN;

    DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
    DECLARE @ErrLine INT = ERROR_LINE();
    DECLARE @ErrNum INT = ERROR_NUMBER();

    PRINT 'Migration failed.';
    RAISERROR('Error %d at line %d: %s', 16, 1, @ErrNum, @ErrLine, @ErrMsg);
END CATCH;

-- Quick verification output
SELECT COUNT(*) AS RolesCount FROM dbo.Roles;
SELECT COUNT(*) AS ListingStatusCount FROM dbo.ListingStatus;
SELECT COUNT(*) AS RoomTypesCount FROM dbo.RoomTypes;
SELECT COUNT(*) AS ProvincesCount FROM dbo.Provinces;
SELECT COUNT(*) AS DistrictsCount FROM dbo.Districts;
SELECT COUNT(*) AS WardsCount FROM dbo.Wards;

SELECT name, is_unique, has_filter, filter_definition
FROM sys.indexes
WHERE object_id = OBJECT_ID('dbo.Users')
  AND (name = 'UX_Users_FirebaseUid_NotNull' OR name LIKE 'UQ__Users__1E65B7F8%');

SELECT name, definition
FROM sys.check_constraints
WHERE parent_object_id = OBJECT_ID('dbo.Listings')
  AND name = 'CK_cover_image_required';
