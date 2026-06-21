using Backend_API.Models.DTOs.Reviews;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý đánh giá (reviews) và hỏi đáp (Q&A) cho tin đăng.
    /// </summary>
    [ApiController]
    [Tags("Reviews")]
    public class ReviewsApiController : ControllerBase
    {
        private readonly IReviewService _reviewService;

        public ReviewsApiController(IReviewService reviewService)
        {
            _reviewService = reviewService;
        }

        /// <summary>
        /// Lấy danh sách đánh giá hoặc hỏi đáp của một tin đăng.
        /// </summary>
        /// <param name="listingId">ID tin đăng</param>
        /// <param name="type">Loại: "review" hoặc "qna"</param>
        /// <returns>Danh sách reviews kèm điểm trung bình</returns>
        [HttpGet("api/listings/{listingId:long}/reviews")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetReviews(long listingId, [FromQuery] string? type = null)
        {
            try
            {
                var items = await _reviewService.GetReviewsByListingAsync(listingId, type, TryGetCurrentUserId());
                var reviewsWithRatings = items.Where(r => r.Type == "review" && r.Rating.HasValue && !r.IsDeleted).ToList();
                double avg = reviewsWithRatings.Count > 0 ? Math.Round(reviewsWithRatings.Average(r => (double)r.Rating!.Value), 1) : 0;
                return Ok(new { success = true, data = items, count = items.Count, averageRating = avg });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [Authorize]
        [HttpGet("api/reviews/me")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMyReviews()
        {
            try
            {
                long userId = GetCurrentUserId();
                var items = await _reviewService.GetMyReviewsAsync(userId);
                return Ok(new { success = true, data = items, count = items.Count });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Tạo đánh giá hoặc hỏi đáp cho tin đăng.
        /// </summary>
        [Authorize]
        [HttpPost("api/listings/{listingId:long}/reviews")]
        [ProducesResponseType(typeof(object), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> CreateReview(long listingId, [FromBody] ReviewCreateDto dto)
        {
            try
            {
                long userId = GetCurrentUserId();
                var result  = await _reviewService.CreateReviewAsync(userId, listingId, dto);
                return Created($"/api/listings/{listingId}/reviews",
                    new { success = true, data = result });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Cập nhật nội dung đánh giá hoặc hỏi đáp trong vòng 30 phút.
        /// </summary>
        [Authorize]
        [HttpPut("api/reviews/{reviewId:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> UpdateReview(long reviewId, [FromBody] ReviewUpdateDto dto)
        {
            try
            {
                long userId = GetCurrentUserId();
                var result = await _reviewService.UpdateReviewAsync(userId, reviewId, dto);
                return Ok(new { success = true, data = result });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Xóa đánh giá hoặc hỏi đáp trong vòng 30 phút.
        /// </summary>
        [Authorize]
        [HttpDelete("api/reviews/{reviewId:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> DeleteReview(long reviewId)
        {
            try
            {
                long userId = GetCurrentUserId();
                await _reviewService.DeleteReviewAsync(userId, reviewId);
                return Ok(new { success = true });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Báo cáo vi phạm đánh giá hoặc hỏi đáp.
        /// </summary>
        [Authorize]
        [HttpPost("api/reviews/{reviewId:long}/report")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> ReportReview(long reviewId)
        {
            try
            {
                long userId = GetCurrentUserId();
                var result = await _reviewService.ReportReviewAsync(userId, reviewId);
                return Ok(new { success = true, data = result });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Phản hồi một đánh giá hoặc hỏi đáp — dành cho chủ trọ.
        /// </summary>
        [Authorize]
        [HttpPost("api/reviews/{reviewId:long}/reply")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> ReplyReview(long reviewId, [FromBody] ReviewReplyDto dto)
        {
            try
            {
                long userId = GetCurrentUserId();
                var result  = await _reviewService.ReplyReviewAsync(userId, reviewId, dto);
                return Ok(new { success = true, data = result });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [Authorize]
        [HttpPost("api/reviews/{reviewId:long}/like")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> ToggleLike(long reviewId)
        {
            try
            {
                long userId = GetCurrentUserId();
                var result = await _reviewService.ToggleLikeAsync(userId, reviewId);
                return Ok(new { success = true, data = result });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        private long GetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(claim) || !long.TryParse(claim, out long userId))
                throw new UnauthorizedAccessException();
            return userId;
        }

        private long? TryGetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            return long.TryParse(claim, out var userId) ? userId : null;
        }
    }
}
