using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Backend_API.Models.DTOs.Rentals;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class RentalService : IRentalService
    {
        private readonly PhongTroDbContext _context;
        private readonly IListingRealtimeNotifier _listingRealtimeNotifier;

        public RentalService(
            PhongTroDbContext context,
            IListingRealtimeNotifier listingRealtimeNotifier)
        {
            _context = context;
            _listingRealtimeNotifier = listingRealtimeNotifier;
        }

        public async Task<RentalResponseDto> CreateRentalAsync(long landlordId, long listingId, RentalCreateDto dto)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var tenant = await _context.Users
                .FirstOrDefaultAsync(u => u.Phone == dto.TenantPhone)
                ?? throw new Exception("Không tìm thấy tài khoản người thuê với số điện thoại này. Vui lòng yêu cầu người thuê đăng ký tài khoản trước.");

            var listing = await _context.Listings
                .Include(l => l.Province)
                .Include(l => l.District)
                .Include(l => l.Ward)
                .Include(l => l.Landlord)
                .Include(l => l.Status)
                .FirstOrDefaultAsync(l => l.ListingId == listingId)
                ?? throw new Exception("Không tìm thấy tin đăng.");

            if (listing.LandlordId != landlordId)
                throw new Exception("Bạn không phải chủ nhà của tin đăng này.");

            if (tenant.UserId == landlordId)
                throw new Exception("Bạn không thể tự cho chính mình thuê phòng.");

            if (string.Equals(listing.Status?.StatusName, "rented", StringComparison.OrdinalIgnoreCase))
                throw new Exception("Tin Ä‘Äƒng nÃ y Ä‘Ã£ Ä‘Æ°á»£c Ä‘Ã¡nh dáº¥u lÃ  Ä‘Ã£ cÃ³ ngÆ°á»i thuÃª.");

            bool listingAlreadyHasTenant = await _context.Rentals
                .AnyAsync(r => r.ListingId == listingId && r.Status == "active");
            if (listingAlreadyHasTenant)
                throw new Exception("Tin Ä‘Äƒng nÃ y Ä‘ang cÃ³ ngÆ°á»i thuÃª hoáº¡t Ä‘á»™ng. HÃ£y káº¿t thÃºc lá»‹ch sá»­ thuÃª hiá»‡n táº¡i trÆ°á»›c.");

            bool alreadyRenting = await _context.Rentals
                .AnyAsync(r => r.ListingId == listingId && r.TenantId == tenant.UserId && r.Status == "active");
            if (alreadyRenting)
                throw new Exception("Người dùng này hiện đang thuê phòng này rồi.");

            var rental = new Rental
            {
                ListingId = listingId,
                TenantId = tenant.UserId,
                LandlordId = landlordId,
                StartDate = dto.StartDate ?? DateTime.UtcNow,
                EndDate = dto.EndDate,
                Status = "active",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            await _context.Rentals.AddAsync(rental);
            listing.StatusId = await GetListingStatusIdAsync("rented");
            listing.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            await _listingRealtimeNotifier.NotifyListingsChangedAsync(
                listing.ListingId,
                "status_changed",
                "rented");

            return new RentalResponseDto
            {
                RentalId = rental.RentalId,
                ListingId = rental.ListingId,
                ListingTitle = listing.Title,
                ListingAddress = BuildListingAddress(listing),
                ListingThumbnail = listing.Image0,
                TenantId = tenant.UserId,
                TenantName = tenant.FullName,
                TenantPhone = tenant.Phone,
                TenantAvatar = tenant.AvatarUrl,
                LandlordId = landlordId,
                LandlordName = listing.Landlord?.FullName ?? "Chủ nhà",
                StartDate = rental.StartDate,
                EndDate = rental.EndDate,
                Status = rental.Status,
                CreatedAt = rental.CreatedAt
            };
        }

        public async Task<List<RentalResponseDto>> GetMyTenantsAsync(long landlordId)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var rentals = await _context.Rentals
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Province)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.District)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Ward)
                .Include(r => r.Tenant)
                .Include(r => r.Landlord)
                .Where(r => r.LandlordId == landlordId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            return rentals.Select(r => new RentalResponseDto
            {
                RentalId = r.RentalId,
                ListingId = r.ListingId,
                ListingTitle = r.Listing.Title,
                ListingAddress = BuildListingAddress(r.Listing),
                ListingThumbnail = r.Listing.Image0,
                TenantId = r.TenantId,
                TenantName = r.Tenant.FullName,
                TenantPhone = r.Tenant.Phone,
                TenantAvatar = r.Tenant.AvatarUrl,
                LandlordId = r.LandlordId,
                LandlordName = r.Landlord.FullName,
                StartDate = r.StartDate,
                EndDate = r.EndDate,
                Status = r.Status,
                CreatedAt = r.CreatedAt
            }).ToList();
        }

        public async Task<List<RentalResponseDto>> GetMyRentedRoomsAsync(long tenantId)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var rentals = await _context.Rentals
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Province)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.District)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Ward)
                .Include(r => r.Tenant)
                .Include(r => r.Landlord)
                .Where(r => r.TenantId == tenantId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            return rentals.Select(r => new RentalResponseDto
            {
                RentalId = r.RentalId,
                ListingId = r.ListingId,
                ListingTitle = r.Listing.Title,
                ListingAddress = BuildListingAddress(r.Listing),
                ListingThumbnail = r.Listing.Image0,
                TenantId = r.TenantId,
                TenantName = r.Tenant.FullName,
                TenantPhone = r.Tenant.Phone,
                TenantAvatar = r.Tenant.AvatarUrl,
                LandlordId = r.LandlordId,
                LandlordName = r.Landlord.FullName,
                StartDate = r.StartDate,
                EndDate = r.EndDate,
                Status = r.Status,
                CreatedAt = r.CreatedAt
            }).ToList();
        }

        private async Task<int> GetListingStatusIdAsync(string statusName)
        {
            var statusId = await _context.ListingStatuses
                .Where(s => s.StatusName.ToLower() == statusName.ToLower())
                .Select(s => (int?)s.StatusId)
                .FirstOrDefaultAsync();

            if (statusId == null)
                throw new Exception($"KhÃ´ng tÃ¬m tháº¥y tráº¡ng thÃ¡i tin Ä‘Äƒng '{statusName}'.");

            return statusId.Value;
        }

        private static string? BuildListingAddress(Listing? listing)
        {
            if (listing == null) return null;

            var parts = new[]
            {
                listing.StreetAddress,
                listing.Ward?.WardName,
                listing.District?.DistrictName,
                listing.Province?.ProvinceName
            }
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Select(x => x!.Trim());

            return string.Join(", ", parts);
        }

        public async Task<RentalResponseDto> ConfirmRentalFromChatAsync(long landlordId, long convId)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var conv = await _context.Conversations
                .Include(c => c.Listing)
                    .ThenInclude(l => l.Province)
                .Include(c => c.Listing)
                    .ThenInclude(l => l.District)
                .Include(c => c.Listing)
                    .ThenInclude(l => l.Ward)
                .Include(c => c.Tenant)
                .Include(c => c.Landlord)
                .FirstOrDefaultAsync(c => c.ConvId == convId)
                ?? throw new Exception("Không tìm thấy cuộc trò chuyện.");

            if (conv.LandlordId != landlordId)
                throw new Exception("Bạn không phải là chủ nhà trong cuộc trò chuyện này.");

            if (conv.ListingId == null)
                throw new Exception("Cuộc trò chuyện này không liên kết với tin đăng nào.");

            long listingId = conv.ListingId.Value;
            long tenantId = conv.TenantId;

            // Check if there is already an active rental for this listing
            var existingRental = await _context.Rentals
                .FirstOrDefaultAsync(r => r.ListingId == listingId && r.Status == "active");

            if (existingRental != null)
            {
                if (existingRental.TenantId == tenantId)
                {
                    return new RentalResponseDto
                    {
                        RentalId = existingRental.RentalId,
                        ListingId = existingRental.ListingId,
                        ListingTitle = conv.Listing?.Title,
                        ListingAddress = BuildListingAddress(conv.Listing),
                        ListingThumbnail = conv.Listing?.Image0,
                        TenantId = tenantId,
                        TenantName = conv.Tenant.FullName,
                        TenantPhone = conv.Tenant.Phone,
                        TenantAvatar = conv.Tenant.AvatarUrl,
                        LandlordId = landlordId,
                        LandlordName = conv.Landlord.FullName,
                        StartDate = existingRental.StartDate,
                        EndDate = existingRental.EndDate,
                        Status = existingRental.Status,
                        CreatedAt = existingRental.CreatedAt
                    };
                }
                throw new Exception("Tin đăng này đã được xác nhận cho một người thuê khác.");
            }

            var rental = new Rental
            {
                ListingId = listingId,
                TenantId = tenantId,
                LandlordId = landlordId,
                StartDate = DateTime.UtcNow,
                Status = "active",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            await _context.Rentals.AddAsync(rental);

            // Update Listing status to 'rented'
            var listing = conv.Listing;
            if (listing != null)
            {
                listing.StatusId = await GetListingStatusIdAsync("rented");
                listing.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();

            // Real-time update
            if (listing != null)
            {
                await _listingRealtimeNotifier.NotifyListingsChangedAsync(
                    listing.ListingId,
                    "status_changed",
                    "rented");
            }

            return new RentalResponseDto
            {
                RentalId = rental.RentalId,
                ListingId = rental.ListingId,
                ListingTitle = listing?.Title,
                ListingAddress = BuildListingAddress(listing),
                ListingThumbnail = listing?.Image0,
                TenantId = tenantId,
                TenantName = conv.Tenant.FullName,
                TenantPhone = conv.Tenant.Phone,
                TenantAvatar = conv.Tenant.AvatarUrl,
                LandlordId = landlordId,
                LandlordName = conv.Landlord.FullName,
                StartDate = rental.StartDate,
                Status = rental.Status,
                CreatedAt = rental.CreatedAt
            };
        }

        public async Task<RentalResponseDto> EndRentalFromChatAsync(long landlordId, long convId)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var conv = await _context.Conversations
                .Include(c => c.Listing)
                    .ThenInclude(l => l.Province)
                .Include(c => c.Listing)
                    .ThenInclude(l => l.District)
                .Include(c => c.Listing)
                    .ThenInclude(l => l.Ward)
                .Include(c => c.Tenant)
                .Include(c => c.Landlord)
                .FirstOrDefaultAsync(c => c.ConvId == convId)
                ?? throw new Exception("Không tìm thấy cuộc trò chuyện.");

            if (conv.LandlordId != landlordId)
                throw new Exception("Bạn không phải là chủ nhà trong cuộc trò chuyện này.");

            if (conv.ListingId == null)
                throw new Exception("Cuộc trò chuyện này không liên kết với tin đăng nào.");

            var rental = await _context.Rentals
                .FirstOrDefaultAsync(r =>
                    r.ListingId == conv.ListingId.Value &&
                    r.TenantId == conv.TenantId &&
                    r.LandlordId == landlordId &&
                    r.Status == "active")
                ?? throw new Exception("Không tìm thấy lịch sử thuê đang hoạt động cho người thuê này.");

            rental.Status = "ended";
            rental.EndDate = DateTime.UtcNow;
            rental.UpdatedAt = DateTime.UtcNow;

            var listing = conv.Listing;
            if (listing != null)
            {
                listing.StatusId = await GetListingStatusIdAsync("active");
                listing.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();

            if (listing != null)
            {
                await _listingRealtimeNotifier.NotifyListingsChangedAsync(
                    listing.ListingId,
                    "status_changed",
                    "active");
            }

            return new RentalResponseDto
            {
                RentalId = rental.RentalId,
                ListingId = rental.ListingId,
                ListingTitle = listing?.Title,
                ListingAddress = BuildListingAddress(listing),
                ListingThumbnail = listing?.Image0,
                TenantId = conv.TenantId,
                TenantName = conv.Tenant.FullName,
                TenantPhone = conv.Tenant.Phone,
                TenantAvatar = conv.Tenant.AvatarUrl,
                LandlordId = landlordId,
                LandlordName = conv.Landlord.FullName,
                StartDate = rental.StartDate,
                EndDate = rental.EndDate,
                Status = rental.Status,
                CreatedAt = rental.CreatedAt
            };
        }

        public async Task EnsureRentalsAndUpgradeReviewsTableAsync()
        {
            if (_context.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory")
                return;

            const string sql = @"
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

-- 3. Drop unique constraint/index on Reviews(listing_id, reviewer_id) if exists to allow Q&As
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'UQ__Reviews__ED9BC2D526F2A52C' AND type = 'UQ')
BEGIN
    ALTER TABLE dbo.Reviews DROP CONSTRAINT UQ__Reviews__ED9BC2D526F2A52C;
END

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'UQ__Reviews__ED9BC2D526F2A52C' AND object_id = OBJECT_ID('dbo.Reviews'))
BEGIN
    DROP INDEX UQ__Reviews__ED9BC2D526F2A52C ON dbo.Reviews;
END

-- 4. Create Unique Filtered Index on Reviews (One Review per Tenant per Listing)
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'UX_Reviews_Listing_Reviewer_Type' AND object_id = OBJECT_ID('dbo.Reviews'))
BEGIN
    CREATE UNIQUE INDEX UX_Reviews_Listing_Reviewer_Type
    ON dbo.Reviews(listing_id, reviewer_id)
    WHERE type = 'review' AND is_deleted = 0;
END

-- 5. Add reputation columns to Users table if they don't exist
IF COL_LENGTH('dbo.Users', 'reputation_score') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD [reputation_score] FLOAT NOT NULL CONSTRAINT DF_Users_ReputationScore DEFAULT (5.0);
END

IF COL_LENGTH('dbo.Users', 'reputation_count') IS NULL
BEGIN
    ALTER TABLE dbo.Users ADD [reputation_count] INT NOT NULL CONSTRAINT DF_Users_ReputationCount DEFAULT (0);
END
";
            await _context.Database.ExecuteSqlRawAsync(sql);
        }
    }
}
