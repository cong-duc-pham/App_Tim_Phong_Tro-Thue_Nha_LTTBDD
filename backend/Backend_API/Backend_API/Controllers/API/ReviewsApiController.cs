using Backend_API.Models.DTOs.Reviews;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý đánh giá (reviews) cho tin đăng: xem, tạo, phản hồi.
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
        /// Lấy danh sách đánh giá của một tin đăng.
        /// </summary>
        /// <param name="listingId">ID tin đăng</param>
        /// <returns>Danh sách reviews kèm điểm trung bình</returns>
        /// <response code="200">Trả về danh sách reviews</response>
        [HttpGet("api/listings/{listingId:long}/reviews")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetReviews(long listingId)
        {
            try
            {
                var items = await _reviewService.GetReviewsByListingAsync(listingId, TryGetCurrentUserId());
                double avg = items.Count > 0 ? Math.Round(items.Average(r => r.Rating), 1) : 0;
                return Ok(new { success = true, data = items, count = items.Count, averageRating = avg });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Tạo đánh giá cho tin đăng (chỉ tenant đã thuê).
        /// </summary>
        /// <param name="listingId">ID tin đăng</param>
        /// <param name="dto">Rating (1-5), nội dung, ảnh đánh giá</param>
        /// <returns>Review vừa tạo</returns>
        /// <response code="201">Tạo review thành công</response>
        /// <response code="401">Chưa đăng nhập</response>
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
        /// Phản hồi (reply) một đánh giá — dành cho chủ trọ.
        /// </summary>
        /// <param name="reviewId">ID review cần phản hồi</param>
        /// <param name="dto">Nội dung phản hồi</param>
        /// <response code="200">Phản hồi thành công</response>
        /// <response code="401">Chưa đăng nhập</response>
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
