using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý thông báo: lấy danh sách, đánh dấu đã đọc, đếm chưa đọc, test FCM.
    /// </summary>
    [ApiController]
    [Route("api/notifications")]
    [Tags("Notifications")]
    public class NotificationsApiController : ControllerBase
    {
        private readonly Backend_API.Helpers.FirebaseMessagingHelper _messagingHelper;
        private readonly INotificationService _notificationService;

        public NotificationsApiController(Backend_API.Helpers.FirebaseMessagingHelper messagingHelper, INotificationService notificationService)
        {
            _messagingHelper = messagingHelper;
            _notificationService = notificationService;
        }

        // ==========================================
        // ENDPOINTS CỦA PHASE 6.2 (NOTIFICATION DB)
        // ==========================================

        /// <summary>
        /// Lấy danh sách thông báo của user hiện tại.
        /// </summary>
        /// <returns>Danh sách thông báo sắp xếp theo thời gian</returns>
        /// <response code="200">Trả về danh sách notifications</response>
        /// <response code="401">Chưa đăng nhập</response>
        [Authorize]
        [HttpGet]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMyNotifications()
        {
            try
            {
                long userId = GetCurrentUserId();
                var notifications = await _notificationService.GetNotificationsAsync(userId);
                return Ok(new { success = true, data = notifications });
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
        /// Đánh dấu thông báo là đã đọc.
        /// </summary>
        /// <param name="id">ID thông báo</param>
        /// <response code="200">Đánh dấu thành công</response>
        /// <response code="401">Chưa đăng nhập</response>
        [Authorize]
        [HttpPut("{id:long}/read")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> MarkAsRead(long id)
        {
            try
            {
                long userId = GetCurrentUserId();
                await _notificationService.MarkAsReadAsync(id, userId);
                return Ok(new { success = true, message = "Đã đánh dấu đã đọc." });
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
        /// Đếm số thông báo chưa đọc.
        /// </summary>
        /// <returns>Số lượng thông báo chưa đọc</returns>
        /// <response code="200">Trả về unreadCount</response>
        /// <response code="401">Chưa đăng nhập</response>
        [Authorize]
        [HttpGet("unread-count")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetUnreadCount()
        {
            try
            {
                long userId = GetCurrentUserId();
                int count = await _notificationService.GetUnreadCountAsync(userId);
                return Ok(new { success = true, unreadCount = count });
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

        // ==========================================
        // ENDPOINTS CỦA PHASE 6.1 (TEST FCM)
        // ==========================================

        public class TestNotificationDto
        {
            public string Token { get; set; } = null!;
            public string Title { get; set; } = null!;
            public string Body { get; set; } = null!;
            public Dictionary<string, string>? Data { get; set; }
        }

        /// <summary>
        /// [DEV] Test gửi push notification qua FCM đến 1 device token.
        /// Chỉ dùng cho testing, không yêu cầu đăng nhập.
        /// </summary>
        /// <param name="dto">FCM Token, Title, Body, Data (optional)</param>
        /// <response code="200">Gửi thông báo thành công</response>
        /// <response code="400">Token trống hoặc gửi thất bại</response>
        [HttpPost("test-send")]
        [AllowAnonymous]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> TestSend([FromBody] TestNotificationDto dto)
        {
            try
            {
                if (string.IsNullOrEmpty(dto.Token))
                    return BadRequest(new { success = false, message = "FCM Token không được để trống." });

                bool isSuccess = await _messagingHelper.SendToDeviceAsync(dto.Token, dto.Title, dto.Body, dto.Data);

                if (isSuccess)
                {
                    return Ok(new { success = true, message = "Đã gửi thông báo thành công." });
                }
                else
                {
                    return BadRequest(new { success = false, message = "Gửi thông báo thất bại. Kiểm tra log." });
                }
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, message = ex.Message });
            }
        }
    }
}
