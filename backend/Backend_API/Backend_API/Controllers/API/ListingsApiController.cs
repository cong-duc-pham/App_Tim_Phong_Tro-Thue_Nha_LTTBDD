using Backend_API.Models.DTOs.Listings;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý tin đăng phòng trọ: CRUD, tìm kiếm, filter, tăng lượt xem.
    /// </summary>
    [ApiController]
    [Route("api/listings")]
    [Tags("Listings")]
    public class ListingsApiController : ControllerBase
    {
        private readonly IListingService _listingService;

        public ListingsApiController(IListingService listingService)
        {
            _listingService = listingService;
        }

        /// <summary>
        /// Lấy danh sách tin đăng có phân trang và bộ lọc.
        /// </summary>
        /// <param name="filter">Bộ lọc: keyword, districtId, minPrice, maxPrice, roomTypeId, page, pageSize</param>
        /// <returns>Danh sách tin đăng và thông tin phân trang</returns>
        /// <response code="200">Trả về danh sách tin đăng</response>
        [HttpGet]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> GetListings([FromQuery] ListingFilterDto filter)
        {
            try
            {
                var (items, total) = await _listingService.GetListingsAsync(filter);
                return Ok(new
                {
                    success   = true,
                    data      = items,
                    totalCount = total,
                    page      = filter.Page,
                    pageSize  = filter.PageSize,
                    totalPages = (int)Math.Ceiling((double)total / filter.PageSize)
                });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách tin đăng của tôi (chủ trọ).
        /// </summary>
        /// <returns>Danh sách tin đăng của user hiện tại</returns>
        /// <response code="200">Trả về danh sách tin đăng của user</response>
        /// <response code="401">Chưa đăng nhập</response>
        [Authorize]
        [HttpGet("my-listings")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMyListings()
        {
            try
            {
                long userId = GetCurrentUserId();
                var items = await _listingService.GetMyListingsAsync(userId);
                return Ok(new { success = true, data = items });
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
        /// Lấy chi tiết tin đăng theo ID.
        /// </summary>
        /// <param name="id">ID của tin đăng</param>
        /// <returns>Chi tiết tin đăng</returns>
        /// <response code="200">Trả về chi tiết tin đăng</response>
        /// <response code="404">Không tìm thấy tin đăng</response>
        [HttpGet("{id:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> GetListing(long id)
        {
            try
            {
                var item = await _listingService.GetListingByIdAsync(id);
                if (item == null)
                    return NotFound(new { success = false, message = "Không tìm thấy tin đăng." });

                return Ok(new { success = true, data = item });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Tạo tin đăng mới. Ảnh upload lên Cloudinary trước, gửi URL ảnh trong body.
        /// </summary>
        /// <param name="dto">Thông tin tin đăng: tiêu đề, mô tả, giá, địa chỉ, ảnh URLs</param>
        /// <returns>Tin đăng vừa tạo</returns>
        /// <response code="201">Tạo tin đăng thành công</response>
        /// <response code="401">Chưa đăng nhập</response>
        [Authorize]
        [HttpPost]
        [ProducesResponseType(typeof(object), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> CreateListing([FromBody] ListingCreateDto dto)
        {
            try
            {
                long userId = GetCurrentUserId();
                var created = await _listingService.CreateListingAsync(userId, dto);
                return Created($"/api/listings/{created.ListingId}",
                    new { success = true, data = created });
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
        /// Cập nhật tin đăng. Chỉ chủ tin mới có quyền sửa.
        /// </summary>
        /// <param name="id">ID tin đăng cần sửa</param>
        /// <param name="dto">Dữ liệu cập nhật</param>
        /// <response code="200">Cập nhật thành công</response>
        /// <response code="403">Không phải chủ tin đăng</response>
        /// <response code="404">Không tìm thấy tin đăng</response>
        [Authorize]
        [HttpPut("{id:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status403Forbidden)]
        [ProducesResponseType(typeof(object), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> UpdateListing(long id, [FromBody] ListingUpdateDto dto)
        {
            try
            {
                long userId  = GetCurrentUserId();
                var existing = await _listingService.GetListingByIdAsync(id);
                if (existing == null)
                    return NotFound(new { success = false, message = "Không tìm thấy tin đăng." });

                if (existing.LandlordId != userId)
                    return Forbid();

                var updated = await _listingService.UpdateListingAsync(id, dto);
                return Ok(new { success = true, data = updated });
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
        /// Xoá (ẩn) tin đăng. Chỉ chủ tin mới có quyền xoá.
        /// </summary>
        /// <param name="id">ID tin đăng cần xoá</param>
        /// <response code="200">Xoá thành công</response>
        /// <response code="403">Không phải chủ tin đăng</response>
        /// <response code="404">Không tìm thấy tin đăng</response>
        [Authorize]
        [HttpDelete("{id:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status403Forbidden)]
        [ProducesResponseType(typeof(object), StatusCodes.Status404NotFound)]
        public async Task<IActionResult> DeleteListing(long id)
        {
            try
            {
                long userId  = GetCurrentUserId();
                var existing = await _listingService.GetListingByIdAsync(id);
                if (existing == null)
                    return NotFound(new { success = false, message = "Không tìm thấy tin đăng." });

                if (existing.LandlordId != userId)
                    return Forbid();

                await _listingService.DeleteListingAsync(id);
                return Ok(new { success = true, message = "Đã ẩn tin đăng thành công." });
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
        /// Tạm ẩn hoặc hiện lại tin đăng (Đánh dấu đã thuê / còn phòng).
        /// </summary>
        /// <param name="id">ID tin đăng</param>
        /// <response code="200">Thay đổi trạng thái thành công</response>
        /// <response code="401">Chưa đăng nhập</response>
        /// <response code="403">Không phải chủ sở hữu bài đăng</response>
        /// <response code="400">Yêu cầu không hợp lệ</response>
        [Authorize]
        [HttpPatch("{id:long}/toggle-status")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(object), StatusCodes.Status403Forbidden)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> ToggleStatus(long id)
        {
            try
            {
                long userId = GetCurrentUserId();
                var updated = await _listingService.ToggleListingStatusAsync(id, userId);
                return Ok(new { success = true, data = updated });
            }
            catch (UnauthorizedAccessException ex)
            {
                if (ex.Message.Contains("chủ sở hữu"))
                    return StatusCode(StatusCodes.Status403Forbidden, new { success = false, message = ex.Message });
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Tăng lượt xem tin đăng. Không yêu cầu đăng nhập.
        /// </summary>
        /// <param name="id">ID tin đăng</param>
        /// <response code="200">Tăng view thành công</response>
        [HttpPost("{id:long}/view")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> IncrementView(long id)
        {
            try
            {
                await _listingService.IncrementViewCountAsync(id);
                return Ok(new { success = true });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        // ─────────────────────────────────────
        // PRIVATE HELPER
        // ─────────────────────────────────────
        private long GetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(claim) || !long.TryParse(claim, out long userId))
                throw new UnauthorizedAccessException();
            return userId;
        }
    }
}
