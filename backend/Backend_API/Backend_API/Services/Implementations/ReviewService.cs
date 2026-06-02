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

        public async Task<List<ReviewResponseDto>> GetReviewsByListingAsync(long listingId)
        {
            var reviews = await _context.Reviews
                .Include(r => r.Reviewer)
                .Include(r => r.ReviewImages)
                .Where(r => r.ListingId == listingId && r.IsApproved == true)
                .OrderByDescending(r => r.CreatedAt)
                .ToListAsync();

            return reviews.Select(MapToDto).ToList();
        }

        public async Task<ReviewResponseDto> ReplyReviewAsync(long landlordId, long reviewId, ReviewReplyDto dto)
        {
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

        private async Task<ReviewResponseDto?> BuildResponseDto(long reviewId)
        {
            var review = await _context.Reviews
                .Include(r => r.Reviewer)
                .Include(r => r.ReviewImages)
                .FirstOrDefaultAsync(r => r.ReviewId == reviewId);

            return review == null ? null : MapToDto(review);
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

        private static ReviewResponseDto MapToDto(Review r) => new()
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
            ImageUrls       = r.ReviewImages.Select(img => img.ImageUrl).ToList()
        };

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
