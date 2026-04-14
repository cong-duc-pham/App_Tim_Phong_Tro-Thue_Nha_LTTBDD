using Backend_API.Models.DTOs.Users;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý sở thích tìm kiếm (preferences) của user: loại phòng, khu vực, ngân sách.
    /// </summary>
    [ApiController]
    [Route("api/preferences")]
    [Authorize]
    [Tags("Preferences")]
    public class PreferencesApiController : ControllerBase
    {
        private readonly IPreferenceService _preferenceService;

        public PreferencesApiController(IPreferenceService preferenceService)
        {
            _preferenceService = preferenceService;
        }

        /// <summary>
        /// Lấy preferences hiện tại của user.
        /// </summary>
        /// <returns>Preferences (null nếu chưa thiết lập)</returns>
        /// <response code="200">Trả về preferences hoặc null</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpGet]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetPreferences()
        {
            try
            {
                long userId = GetCurrentUserId();
                var prefs = await _preferenceService.GetPreferencesAsync(userId);
                
                if (prefs == null)
                    return Ok(new { success = true, data = (object?)null, message = "User chưa có preference." });
                
                return Ok(new { success = true, data = prefs });
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
        /// Lưu/Cập nhật preferences của user.
        /// </summary>
        /// <param name="dto">Preferences: loại phòng, giá min/max, khu vực, tiện ích</param>
        /// <returns>Preferences đã lưu</returns>
        /// <response code="200">Lưu preferences thành công</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpPost]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> SavePreferences([FromBody] UserPreferenceDto dto)
        {
            try
            {
                long userId = GetCurrentUserId();
                var saved = await _preferenceService.SavePreferencesAsync(userId, dto);
                return Ok(new { success = true, data = saved });
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
