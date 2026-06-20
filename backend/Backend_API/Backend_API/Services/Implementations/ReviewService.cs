using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Backend_API.Models.DTOs.Reviews;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class ReviewService : IReviewService
    {
        private readonly PhongTroDbContext _context;
        private readonly INotificationService _notificationService;

        public ReviewService(
            PhongTroDbContext context,
            INotificationService notificationService)
        {
            _context = context;
            _notificationService = notificationService;
        }

        public async Task<ReviewResponseDto> CreateReviewAsync(long reviewerId, long listingId, ReviewCreateDto dto)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var listing = await _context.Listings
                .FirstOrDefaultAsync(l => l.ListingId == listingId)
                ?? throw new Exception("Không tìm thấy tin đăng.");

            bool isVerifiedTenant = await _context.Rentals
                .AnyAsync(r => r.ListingId == listingId && r.TenantId == reviewerId);

            string reviewType = (dto.Type ?? "review").ToLower();
            if (reviewType != "review" && reviewType != "qna")
            {
                reviewType = "review";
            }

            if (reviewType == "review")
            {
                if (listing.LandlordId == reviewerId)
                    throw new Exception("Bạn không thể đánh giá chính phòng của mình.");

                if (!isVerifiedTenant)
                    throw new Exception("Chỉ người dùng đã từng thuê phòng này mới được đánh giá.");

                bool alreadyReviewed = await _context.Reviews
                    .AnyAsync(r => r.ListingId == listingId && r.ReviewerId == reviewerId && r.Type == "review" && !r.IsDeleted);
                if (alreadyReviewed)
                    throw new Exception("Bạn đã đánh giá tin đăng này rồi.");

                if (dto.Rating == null || dto.Rating < 1 || dto.Rating > 5)
                    throw new Exception("Vui lòng chọn số sao từ 1 đến 5.");
            }
            else
            {
                // Q&A logic: no rating, clear rating fields
                dto.Rating = null;
                dto.RatingLocation = null;
                dto.RatingPrice = null;
                dto.RatingCleanness = null;
                dto.RatingSecurity = null;
            }

            // Spam and Broker keyword detection
            bool containsSpam = false;
            if (!string.IsNullOrWhiteSpace(dto.Comment))
            {
                string content = dto.Comment.ToLower();
                bool hasPhone = Regex.IsMatch(content, @"(0[35789])+([0-9]{8})\b");
                bool hasLink = content.Contains("zalo.me") || content.Contains("http") || content.Contains("facebook.com") || content.Contains("t.me") || content.Contains("contact");
                containsSpam = hasPhone || hasLink;
            }

            string reviewStatus = (containsSpam && !isVerifiedTenant) ? "pending" : "approved";

            var review = new Review
            {
                ListingId = listingId,
                ReviewerId = reviewerId,
                Rating = dto.Rating,
                Comment = dto.Comment,
                RatingLocation = dto.RatingLocation,
                RatingPrice = dto.RatingPrice,
                RatingCleanness = dto.RatingCleanness,
                RatingSecurity = dto.RatingSecurity,
                IsApproved = reviewStatus == "approved",
                Type = reviewType,
                Status = reviewStatus,
                ReportCount = 0,
                IsDeleted = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            await _context.Reviews.AddAsync(review);
            await _context.SaveChangesAsync();

            if (dto.ImageUrls != null && dto.ImageUrls.Count > 0)
            {
                var images = dto.ImageUrls.Select(url => new ReviewImage
                {
                    ReviewId = review.ReviewId,
                    ImageUrl = url,
                    CloudinaryPublicId = ExtractPublicIdFromCloudinaryUrl(url),
                    CreatedAt = DateTime.UtcNow
                });
                await _context.ReviewImages.AddRangeAsync(images);
                await _context.SaveChangesAsync();
            }

            var result = await BuildResponseDto(review.ReviewId)
                         ?? throw new Exception("Tạo đánh giá thất bại.");

            // Notify landlord
            if (reviewStatus == "approved")
            {
                await NotifyLandlordReviewCreatedAsync(listing, result);
            }

            return result;
        }

        public async Task<List<ReviewResponseDto>> GetReviewsByListingAsync(long listingId, string? type = null, long? currentUserId = null)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var query = _context.Reviews
                .Include(r => r.Reviewer)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Province)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.District)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Ward)
                .Include(r => r.ReviewImages)
                .Include(r => r.ReviewLikes)
                .Where(r => r.ListingId == listingId && r.Status == "approved");

            if (!string.IsNullOrWhiteSpace(type))
            {
                string normType = type.ToLower();
                query = query.Where(r => r.Type == normType);
            }

            var reviews = await query.OrderByDescending(r => r.CreatedAt).ToListAsync();

            // Load rentals to map IsVerifiedTenant
            var rentedListingUserIds = await _context.Rentals
                .Where(r => r.ListingId == listingId)
                .Select(r => r.TenantId)
                .ToListAsync();

            return reviews.Select(r => MapToDto(r, rentedListingUserIds.Contains(r.ReviewerId), currentUserId)).ToList();
        }

        public async Task<List<ReviewResponseDto>> GetMyReviewsAsync(long reviewerId)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var reviews = await _context.Reviews
                .Include(r => r.Reviewer)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Province)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.District)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Ward)
                .Include(r => r.ReviewImages)
                .Include(r => r.ReviewLikes)
                .Where(r => r.ReviewerId == reviewerId)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            var userRentedListings = await _context.Rentals
                .Where(r => r.TenantId == reviewerId)
                .Select(r => r.ListingId)
                .ToListAsync();

            return reviews.Select(r => MapToDto(r, userRentedListings.Contains(r.ListingId), reviewerId)).ToList();
        }

        public async Task<ReviewResponseDto> UpdateReviewAsync(long reviewerId, long reviewId, ReviewUpdateDto dto)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var review = await _context.Reviews
                .Include(r => r.Listing)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId)
                ?? throw new Exception("Không tìm thấy đánh giá.");

            if (review.ReviewerId != reviewerId)
                throw new UnauthorizedAccessException("Bạn không có quyền sửa đánh giá này.");

            if (review.IsDeleted)
                throw new Exception("Bình luận này đã bị xóa.");

            if (review.CreatedAt.HasValue && (DateTime.UtcNow - review.CreatedAt.Value).TotalMinutes > 30)
                throw new Exception("Đã quá thời hạn 30 phút để chỉnh sửa bình luận.");

            if (review.Type == "review")
            {
                if (dto.Rating == null || dto.Rating < 1 || dto.Rating > 5)
                    throw new Exception("Vui lòng chọn số sao từ 1 đến 5.");

                review.Rating = dto.Rating;
                review.RatingLocation = dto.RatingLocation;
                review.RatingPrice = dto.RatingPrice;
                review.RatingCleanness = dto.RatingCleanness;
                review.RatingSecurity = dto.RatingSecurity;
            }

            review.Comment = dto.Comment;
            review.UpdatedAt = DateTime.UtcNow;

            // Re-detect spam
            bool isVerifiedTenant = await _context.Rentals
                .AnyAsync(r => r.ListingId == review.ListingId && r.TenantId == reviewerId);

            bool containsSpam = false;
            if (!string.IsNullOrWhiteSpace(dto.Comment))
            {
                string content = dto.Comment.ToLower();
                bool hasPhone = Regex.IsMatch(content, @"(0[35789])+([0-9]{8})\b");
                bool hasLink = content.Contains("zalo.me") || content.Contains("http") || content.Contains("facebook.com") || content.Contains("t.me") || content.Contains("contact");
                containsSpam = hasPhone || hasLink;
            }

            review.Status = (containsSpam && !isVerifiedTenant) ? "pending" : "approved";
            review.IsApproved = review.Status == "approved";

            await _context.SaveChangesAsync();

            return await BuildResponseDto(reviewId, reviewerId)
                   ?? throw new Exception("Cập nhật đánh giá thất bại.");
        }

        public async Task DeleteReviewAsync(long reviewerId, long reviewId)
        {
            var review = await _context.Reviews
                .Include(r => r.ReviewImages)
                .Include(r => r.ReviewLikes)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId)
                ?? throw new Exception("Không tìm thấy đánh giá.");

            if (review.ReviewerId != reviewerId)
                throw new UnauthorizedAccessException("Bạn không có quyền xóa đánh giá này.");

            if (review.CreatedAt.HasValue && (DateTime.UtcNow - review.CreatedAt.Value).TotalMinutes > 30)
                throw new Exception("Đã quá thời hạn 30 phút để xóa bình luận.");

            if (!string.IsNullOrWhiteSpace(review.LandlordReply))
            {
                // Soft delete
                review.IsDeleted = true;
                review.Comment = "Bình luận này đã bị xóa.";
                review.Rating = null;
                review.RatingLocation = null;
                review.RatingPrice = null;
                review.RatingCleanness = null;
                review.RatingSecurity = null;
                review.Status = "approved";
                review.IsApproved = true;

                if (review.ReviewImages.Count > 0)
                {
                    _context.ReviewImages.RemoveRange(review.ReviewImages);
                }
            }
            else
            {
                // Hard delete
                if (review.ReviewImages.Count > 0)
                {
                    _context.ReviewImages.RemoveRange(review.ReviewImages);
                }

                if (review.ReviewLikes.Count > 0)
                {
                    _context.ReviewLikes.RemoveRange(review.ReviewLikes);
                }

                _context.Reviews.Remove(review);
            }

            await _context.SaveChangesAsync();
        }

        public async Task<ReviewResponseDto> ReportReviewAsync(long userId, long reviewId)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var review = await _context.Reviews
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId)
                ?? throw new Exception("Không tìm thấy bình luận.");

            review.ReportCount += 1;
            if (review.ReportCount >= 5)
            {
                review.Status = "hidden";
                review.IsApproved = false;
            }

            await _context.SaveChangesAsync();

            return await BuildResponseDto(reviewId, userId)
                   ?? throw new Exception("Báo cáo vi phạm thất bại.");
        }

        public async Task<ReviewResponseDto> ReplyReviewAsync(long landlordId, long reviewId, ReviewReplyDto dto)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var review = await _context.Reviews
                .Include(r => r.Listing)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId)
                ?? throw new Exception("Không tìm thấy đánh giá.");

            if (review.Listing.LandlordId != landlordId)
                throw new Exception("Bạn không có quyền phản hồi đánh giá này.");

            review.LandlordReply = dto.Reply;
            review.RepliedAt = DateTime.UtcNow;
            review.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            var result = await BuildResponseDto(reviewId)
                    ?? throw new Exception("Phản hồi thất bại.");

            // Notify Tenant
            try
            {
                await _notificationService.CreateAndSendAsync(
                    review.ReviewerId,
                    "Chủ nhà đã phản hồi bình luận của bạn",
                    $"Chủ nhà vừa trả lời bình luận của bạn tại tin \"{review.Listing.Title}\".",
                    "review_replied",
                    review.ReviewId,
                    "review");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Review] Could not notify tenant for reply {review.ReviewId}: {ex.Message}");
            }

            return result;
        }

        public async Task<ReviewResponseDto> ToggleLikeAsync(long userId, long reviewId)
        {
            await EnsureRentalsAndUpgradeReviewsTableAsync();

            var review = await _context.Reviews
                .Include(r => r.Listing)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId && r.Status == "approved");
            if (review == null)
                throw new Exception("Không tìm thấy đánh giá.");

            if (review.Listing.LandlordId == userId)
                throw new Exception("Chủ bài đăng không thể thích bình luận của bài mình.");

            var existing = await _context.ReviewLikes
                .FirstOrDefaultAsync(x => x.ReviewId == reviewId && x.UserId == userId);

            if (existing != null)
            {
                _context.ReviewLikes.Remove(existing);
            }
            else
            {
                await _context.ReviewLikes.AddAsync(new ReviewLike
                {
                    ReviewId = reviewId,
                    UserId = userId,
                    CreatedAt = DateTime.UtcNow
                });
            }

            await _context.SaveChangesAsync();

            return await BuildResponseDto(reviewId, userId)
                   ?? throw new Exception("Cập nhật lượt thích thất bại.");
        }

        private async Task<ReviewResponseDto?> BuildResponseDto(long reviewId, long? currentUserId = null)
        {
            var review = await _context.Reviews
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Province)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.District)
                .Include(r => r.Listing)
                    .ThenInclude(l => l.Ward)
                .Include(r => r.Reviewer)
                .Include(r => r.ReviewImages)
                .Include(r => r.ReviewLikes)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId);

            if (review == null) return null;

            bool isVerifiedTenant = await _context.Rentals
                .AnyAsync(r => r.ListingId == review.ListingId && r.TenantId == review.ReviewerId);

            return MapToDto(review, isVerifiedTenant, currentUserId);
        }

        private async Task NotifyLandlordReviewCreatedAsync(Listing listing, ReviewResponseDto review)
        {
            try
            {
                var reviewerName = string.IsNullOrWhiteSpace(review.ReviewerName)
                    ? "Người dùng"
                    : review.ReviewerName.Trim();
                var comment = review.Comment?.Trim();

                string title = review.Type == "review" ? "Đánh giá mới trên tin đăng" : "Câu hỏi mới trên tin đăng";
                string body = review.Type == "review"
                    ? $"{reviewerName} vừa đánh giá {review.Rating}/5 sao: {TrimForNotification(comment ?? "")}"
                    : $"{reviewerName} vừa gửi câu hỏi: {TrimForNotification(comment ?? "")}";

                await _notificationService.CreateAndSendAsync(
                    listing.LandlordId,
                    title,
                    body,
                    review.Type == "review" ? "listing_reviewed" : "listing_qna",
                    listing.ListingId,
                    "listing");
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Review] Could not notify landlord for review {review.ReviewId}: {ex.Message}");
            }
        }

        private static string TrimForNotification(string value)
        {
            const int maxLength = 120;
            return value.Length <= maxLength ? value : value[..maxLength].TrimEnd() + "...";
        }

        private static ReviewResponseDto MapToDto(Review r, bool isVerifiedTenant, long? currentUserId = null) => new()
        {
            ReviewId = r.ReviewId,
            ReviewerId = r.ReviewerId,
            ReviewerName = r.Reviewer?.FullName ?? string.Empty,
            ReviewerAvatar = r.Reviewer?.AvatarUrl,
            ListingId = r.ListingId,
            ListingTitle = r.Listing?.Title,
            ListingAddress = BuildListingAddress(r.Listing),
            ListingPrice = r.Listing?.Price,
            ListingImage = r.Listing?.Image0,
            Rating = r.Rating,
            Comment = r.Comment,
            RatingLocation = r.RatingLocation,
            RatingPrice = r.RatingPrice,
            RatingCleanness = r.RatingCleanness,
            RatingSecurity = r.RatingSecurity,
            IsApproved = r.IsApproved,
            LandlordReply = r.LandlordReply,
            RepliedAt = r.RepliedAt,
            CreatedAt = r.CreatedAt,
            LikeCount = r.ReviewLikes.Count,
            IsLiked = currentUserId.HasValue && r.ReviewLikes.Any(x => x.UserId == currentUserId.Value),
            Type = r.Type,
            Status = r.Status,
            IsVerifiedTenant = isVerifiedTenant,
            IsDeleted = r.IsDeleted,
            ImageUrls = r.ReviewImages.Select(img => img.ImageUrl).ToList()
        };

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

        private async Task EnsureReviewLikesTableAsync()
        {
            if (_context.Database.ProviderName == "Microsoft.EntityFrameworkCore.InMemory")
                return;

            const string sql = @"
IF OBJECT_ID(N'[dbo].[ReviewLikes]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ReviewLikes] (
        [review_like_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [review_id] BIGINT NOT NULL,
        [user_id] BIGINT NOT NULL,
        [created_at] DATETIME2 NOT NULL CONSTRAINT [DF_ReviewLikes_created_at] DEFAULT SYSUTCDATETIME(),
        [UX_ReviewLikes_Review_User] UNIQUE ([review_id], [user_id]),
        [FK_ReviewLikes_Reviews] FOREIGN KEY ([review_id]) REFERENCES [dbo].[Reviews]([review_id]) ON DELETE CASCADE,
        [FK_ReviewLikes_Users] FOREIGN KEY ([user_id]) REFERENCES [dbo].[Users]([user_id])
    );
END";

            await _context.Database.ExecuteSqlRawAsync(sql);
        }

        private async Task EnsureRentalsAndUpgradeReviewsTableAsync()
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
";
            await _context.Database.ExecuteSqlRawAsync(sql);
        }

        private static string ExtractPublicIdFromCloudinaryUrl(string url)
        {
            try
            {
                var uri = new Uri(url);
                var path = uri.AbsolutePath.Trim('/');
                var marker = "/upload/";
                var idx = path.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
                if (idx < 0) return url;

                var rest = path[(idx + marker.Length)..];
                if (rest.StartsWith("v") && rest.Contains('/'))
                {
                    var slash = rest.IndexOf('/');
                    var version = rest[..slash];
                    if (version.Length > 1 && int.TryParse(version[1..], out _))
                    {
                        rest = rest[(slash + 1)..];
                    }
                }

                var dot = rest.LastIndexOf('.');
                return dot > 0 ? rest[..dot] : rest;
            }
            catch
            {
                return url;
            }
        }
    }
}
