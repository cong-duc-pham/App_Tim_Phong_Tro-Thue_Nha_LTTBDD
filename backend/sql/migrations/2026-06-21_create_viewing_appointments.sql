-- ============================================================
-- PHONGTRO DB - Migration: Create ViewingAppointments table
-- Date: 2026-06-21
-- Purpose: Support booking property viewing appointments
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

PRINT '--- Start migration: Create ViewingAppointments ---';

BEGIN TRY
    BEGIN TRAN;

    IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE object_id = OBJECT_ID('dbo.ViewingAppointments'))
    BEGIN
        PRINT 'Creating table dbo.ViewingAppointments...';
        CREATE TABLE dbo.ViewingAppointments
        (
            appointment_id BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ViewingAppointments PRIMARY KEY,
            listing_id BIGINT NOT NULL,
            tenant_id BIGINT NOT NULL,
            landlord_id BIGINT NOT NULL,
            scheduled_at DATETIME2 NOT NULL,
            status VARCHAR(20) NOT NULL CONSTRAINT DF_ViewingAppointments_Status DEFAULT ('pending'),
            tenant_note NVARCHAR(500) NULL,
            landlord_note NVARCHAR(500) NULL,
            created_at DATETIME2 NULL CONSTRAINT DF_ViewingAppointments_CreatedAt DEFAULT (GETDATE()),
            updated_at DATETIME2 NULL CONSTRAINT DF_ViewingAppointments_UpdatedAt DEFAULT (GETDATE()),
            CONSTRAINT FK_ViewingAppointments_Listings
                FOREIGN KEY (listing_id) REFERENCES dbo.Listings(listing_id),
            CONSTRAINT FK_ViewingAppointments_Tenants
                FOREIGN KEY (tenant_id) REFERENCES dbo.Users(user_id),
            CONSTRAINT FK_ViewingAppointments_Landlords
                FOREIGN KEY (landlord_id) REFERENCES dbo.Users(user_id),
            CONSTRAINT CK_ViewingAppointments_Status
                CHECK (status IN ('pending', 'confirmed', 'declined', 'cancelled')),
            CONSTRAINT CK_ViewingAppointments_NotSelf
                CHECK (tenant_id <> landlord_id)
        );

        PRINT 'Creating indexes for ViewingAppointments...';
        CREATE INDEX IX_ViewingAppointments_Tenant
            ON dbo.ViewingAppointments(tenant_id, scheduled_at);

        CREATE INDEX IX_ViewingAppointments_Landlord
            ON dbo.ViewingAppointments(landlord_id, scheduled_at);

        CREATE INDEX IX_ViewingAppointments_Listing
            ON dbo.ViewingAppointments(listing_id);
    END
    ELSE
    BEGIN
        PRINT 'Table dbo.ViewingAppointments already exists.';
    END

    COMMIT TRAN;
    PRINT '--- Migration completed successfully ---';
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
