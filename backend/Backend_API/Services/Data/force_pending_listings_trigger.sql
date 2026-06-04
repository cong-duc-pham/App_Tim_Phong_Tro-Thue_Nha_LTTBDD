USE [PhongTroDB];
GO

IF OBJECT_ID('dbo.trg_Listings_ForcePendingOnInsert', 'TR') IS NOT NULL
    DROP TRIGGER dbo.trg_Listings_ForcePendingOnInsert;
GO

CREATE TRIGGER dbo.trg_Listings_ForcePendingOnInsert
ON dbo.Listings
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @PendingStatusId int;
    SELECT @PendingStatusId = status_id
    FROM dbo.ListingStatus
    WHERE status_name = 'pending';

    IF @PendingStatusId IS NULL
        RETURN;

    UPDATE l
    SET
        status_id = @PendingStatusId,
        updated_at = COALESCE(l.updated_at, GETDATE())
    FROM dbo.Listings l
    INNER JOIN inserted i ON i.listing_id = l.listing_id
    WHERE l.status_id <> @PendingStatusId;
END;
GO

