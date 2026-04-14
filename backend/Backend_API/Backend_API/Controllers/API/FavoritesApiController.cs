using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý danh sách yêu thích: thêm/bỏ, kiểm tra trạng thái.
    /// </summary>
    [ApiController]
    [Route("api/favorites")]
    [Authorize]
    [Tags("Favorites")]
    public class FavoritesApiController : ControllerBase
    {
        private readonly IFavoriteService _favoriteService;

        public FavoritesApiController(IFavoriteService favoriteService)
        {
            _favoriteService = favoriteService;
        }

        /// <summary>
        /// Toggle yêu thích: Gọi 1 lần = thêm, gọi lần 2 = bỏ.
        /// Response trả về trạng thái hiện tại sau thao tác.
        /// </summary>
        /// <param name="listingId">ID tin đăng cần toggle</param>
        /// <response code="200">Toggle thành công, trả về trạng thái isFavorite</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpPost("{listingId:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> ToggleFavorite(long listingId)
        {
            try
            {
                long userId   = GetCurrentUserId();
                bool isSaved  = await _favoriteService.ToggleFavoriteAsync(userId, listingId);
                string message = isSaved ? "Đã thêm vào yêu thích." : "Đã bỏ khỏi yêu thích.";
                return Ok(new { success = true, isFavorite = isSaved, message });
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
        /// Lấy danh sách tin đăng đã lưu của tôi.
        /// </summary>
        /// <returns>Danh sách tin đăng yêu thích</returns>
        /// <response code="200">Trả về danh sách favorites</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpGet]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetFavorites()
        {
            try
            {
                long userId = GetCurrentUserId();
                var items   = await _favoriteService.GetFavoritesAsync(userId);
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
        /// Kiểm tra tin đăng cụ thể có đang được yêu thích không.
        /// </summary>
        /// <param name="listingId">ID tin đăng cần kiểm tra</param>
        /// <response code="200">Trả về trạng thái isFavorite</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpGet("{listingId:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> IsFavorite(long listingId)
        {
            try
            {
                long userId    = GetCurrentUserId();
                bool isFav     = await _favoriteService.IsFavoriteAsync(userId, listingId);
                return Ok(new { success = true, isFavorite = isFav });
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
    }
}
