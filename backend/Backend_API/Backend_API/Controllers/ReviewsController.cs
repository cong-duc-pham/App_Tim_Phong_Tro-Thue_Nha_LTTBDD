using Backend_API.Data;
using Backend_API.Models.DTOs;
using Backend_API.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers;

[ApiController]
[Route("api/listings/{listingId:long}/reviews")]
[Authorize]
public class ReviewsController : ControllerBase
{
    private readonly AppDbContext _db;
    public ReviewsController(AppDbContext db) => _db = db;

    /// <summary>Lấy danh sách đánh giá của tin đăng (public)</summary>
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetReviews(long listingId)
    {
        var reviews = await _db.Reviews
            .Include(r => r.Reviewer)
            .Include(r => r.Images)
            .Where(r => r.ListingId == listingId && r.IsApproved)
            .OrderByDescending(r => r.CreatedAt)
            .Select(r => new
            {
                r.ReviewId,
                r.Rating,
                r.Comment,
                r.RatingLocation, r.RatingPrice, r.RatingCleanness, r.RatingSecurity,
                r.LandlordReply, r.RepliedAt,
                r.CreatedAt,
                Reviewer = new { r.Reviewer.FullName, r.Reviewer.AvatarUrl },
                Images = r.Images.Select(i => i.ImageUrl).ToList()
            })
            .ToListAsync();

        var avgRating = reviews.Any() ? reviews.Average(r => r.Rating) : 0;

        return Ok(new ApiResponse<object>(true, null, new
        {
            AverageRating = Math.Round(avgRating, 1),
            TotalReviews = reviews.Count,
            Reviews = reviews
        }));
    }

    /// <summary>Gửi đánh giá phòng</summary>
    [HttpPost]
    public async Task<IActionResult> AddReview(long listingId, [FromBody] CreateReviewRequest req)
    {
        var userId = GetUserId();
        var exists = await _db.Reviews.AnyAsync(r => r.ListingId == listingId && r.ReviewerId == userId);
        if (exists)
            return Conflict(new ApiResponse<object>(false, "Bạn đã đánh giá phòng này rồi", null));

        var review = new Review
        {
            ListingId = listingId,
            ReviewerId = userId!.Value,
            Rating = (byte)req.Rating,
            Comment = req.Comment,
            RatingLocation = req.RatingLocation.HasValue ? (byte?)req.RatingLocation.Value : null,
            RatingPrice = req.RatingPrice.HasValue ? (byte?)req.RatingPrice.Value : null,
            RatingCleanness = req.RatingCleanness.HasValue ? (byte?)req.RatingCleanness.Value : null,
            RatingSecurity = req.RatingSecurity.HasValue ? (byte?)req.RatingSecurity.Value : null,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _db.Reviews.Add(review);
        await _db.SaveChangesAsync();

        if (req.ImageUrls?.Any() == true)
        {
            _db.ReviewImages.AddRange(req.ImageUrls.Select(url => new ReviewImage
            {
                ReviewId = review.ReviewId,
                ImageUrl = url,
                CreatedAt = DateTime.UtcNow
            }));
            await _db.SaveChangesAsync();
        }

        return StatusCode(201, new ApiResponse<object>(true, "Đánh giá đã gửi, chờ admin duyệt", new { review.ReviewId }));
    }

    private long? GetUserId()
    {
        var claim = User.FindFirst("userId")?.Value;
        return long.TryParse(claim, out var id) ? id : null;
    }
}

public record CreateReviewRequest(
    int Rating,
    string? Comment,
    int? RatingLocation,
    int? RatingPrice,
    int? RatingCleanness,
    int? RatingSecurity,
    List<string>? ImageUrls
);
