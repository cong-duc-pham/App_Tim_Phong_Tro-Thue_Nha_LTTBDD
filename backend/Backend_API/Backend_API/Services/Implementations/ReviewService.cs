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
            await EnsureReviewLikesTableAsync();

            // Validate: không tự review phòng mình
            var listing = await _context.Listings
                .FirstOrDefaultAsync(l => l.ListingId == listingId)
                ?? throw new Exception("Không tìm thấy tin đăng.");

            if (listing.LandlordId == reviewerId)
                throw new Exception("Bạn không thể đánh giá chính phòng của mình.");

            // Validate: chưa review listing này (1 user = 1 review / listing)
            bool alreadyReviewed = await _context.Reviews
                .AnyAsync(r => r.ListingId == listingId && r.ReviewerId == reviewerId);
            if (alreadyReviewed)
                throw new Exception("Bạn đã đánh giá tin đăng này rồi.");

            // Insert review
            var review = new Review
            {
                ListingId        = listingId,
                ReviewerId       = reviewerId,
                Rating           = dto.Rating,
                Comment          = dto.Comment,
                RatingLocation   = dto.RatingLocation,
                RatingPrice      = dto.RatingPrice,
                RatingCleanness  = dto.RatingCleanness,
                RatingSecurity   = dto.RatingSecurity,
                IsApproved       = true, // Auto-approve; có thể chuyển thành false nếu cần kiểm duyệt
                CreatedAt        = DateTime.UtcNow,
                UpdatedAt        = DateTime.UtcNow
            };

            await _context.Reviews.AddAsync(review);
            await _context.SaveChangesAsync(); // cần ReviewId trước

            // Insert ReviewImages (Cloudinary URLs)
            if (dto.ImageUrls.Count > 0)
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

            // Load lại để trả về DTO đầy đủ
            var result = await BuildResponseDto(review.ReviewId)
                         ?? throw new Exception("Tạo đánh giá thất bại.");

            await NotifyLandlordReviewCreatedAsync(listing, result);

            return result;
        }

        public async Task<List<ReviewResponseDto>> GetReviewsByListingAsync(long listingId, long? currentUserId = null)
        {
            await EnsureReviewLikesTableAsync();

            var reviews = await _context.Reviews
                .Include(r => r.Reviewer)
                .Include(r => r.ReviewImages)
                .Include(r => r.ReviewLikes)
                .Where(r => r.ListingId == listingId && r.IsApproved == true)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            return reviews.Select(r => MapToDto(r, currentUserId)).ToList();
        }

        public async Task<ReviewResponseDto> ReplyReviewAsync(long landlordId, long reviewId, ReviewReplyDto dto)
        {
            await EnsureReviewLikesTableAsync();

            var review = await _context.Reviews
                .Include(r => r.Listing)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId)
                ?? throw new Exception("Không tìm thấy đánh giá.");

            // Chỉ chủ nhà của listing mới được reply
            if (review.Listing.LandlordId != landlordId)
                throw new Exception("Bạn không có quyền phản hồi đánh giá này.");

            review.LandlordReply = dto.Reply;
            review.RepliedAt     = DateTime.UtcNow;
            review.UpdatedAt     = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            return await BuildResponseDto(reviewId)
                   ?? throw new Exception("Phản hồi thất bại.");
        }

        // ── Private helpers

        public async Task<ReviewResponseDto> ToggleLikeAsync(long userId, long reviewId)
        {
            await EnsureReviewLikesTableAsync();

            var review = await _context.Reviews
                .Include(r => r.Listing)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId && r.IsApproved == true);
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
                .Include(r => r.Reviewer)
                .Include(r => r.ReviewImages)
                .Include(r => r.ReviewLikes)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId);

            return review == null ? null : MapToDto(review, currentUserId);
        }

        private async Task NotifyLandlordReviewCreatedAsync(Listing listing, ReviewResponseDto review)
        {
            try
            {
                var reviewerName = string.IsNullOrWhiteSpace(review.ReviewerName)
                    ? "Người thuê"
                    : review.ReviewerName.Trim();
                var comment = review.Comment?.Trim();
                var body = string.IsNullOrWhiteSpace(comment)
                    ? $"{reviewerName} vừa đánh giá {review.Rating}/5 sao cho tin \"{listing.Title}\"."
                    : $"{reviewerName} vừa đánh giá {review.Rating}/5 sao: {TrimForNotification(comment)}";

                await _notificationService.CreateAndSendAsync(
                    listing.LandlordId,
                    "Tin đăng có đánh giá mới",
                    body,
                    "listing_reviewed",
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

        private static ReviewResponseDto MapToDto(Review r, long? currentUserId = null) => new()
        {
            ReviewId       = r.ReviewId,
            ReviewerId     = r.ReviewerId,
            ReviewerName   = r.Reviewer?.FullName ?? string.Empty,
            ReviewerAvatar = r.Reviewer?.AvatarUrl,
            Rating         = r.Rating,
            Comment        = r.Comment,
            RatingLocation  = r.RatingLocation,
            RatingPrice     = r.RatingPrice,
            RatingCleanness = r.RatingCleanness,
            RatingSecurity  = r.RatingSecurity,
            IsApproved      = r.IsApproved,
            LandlordReply   = r.LandlordReply,
            RepliedAt       = r.RepliedAt,
            CreatedAt       = r.CreatedAt,
            LikeCount       = r.ReviewLikes.Count,
            IsLiked         = currentUserId.HasValue && r.ReviewLikes.Any(x => x.UserId == currentUserId.Value),
            ImageUrls       = r.ReviewImages.Select(img => img.ImageUrl).ToList()
        };

        private async Task EnsureReviewLikesTableAsync()
        {
            const string sql = @"
IF OBJECT_ID(N'[dbo].[ReviewLikes]', N'U') IS NULL
BEGIN
    CREATE TABLE [dbo].[ReviewLikes] (
        [review_like_id] BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        [review_id] BIGINT NOT NULL,
        [user_id] BIGINT NOT NULL,
        [created_at] DATETIME2 NOT NULL CONSTRAINT [DF_ReviewLikes_created_at] DEFAULT SYSUTCDATETIME(),
        CONSTRAINT [UX_ReviewLikes_Review_User] UNIQUE ([review_id], [user_id]),
        CONSTRAINT [FK_ReviewLikes_Reviews] FOREIGN KEY ([review_id]) REFERENCES [dbo].[Reviews]([review_id]) ON DELETE CASCADE,
        CONSTRAINT [FK_ReviewLikes_Users] FOREIGN KEY ([user_id]) REFERENCES [dbo].[Users]([user_id])
    );
END";

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
