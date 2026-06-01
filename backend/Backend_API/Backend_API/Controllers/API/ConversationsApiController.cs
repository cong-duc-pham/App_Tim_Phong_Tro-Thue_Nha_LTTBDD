using Backend_API.Models.DTOs.Chat;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý hội thoại chat: tạo conversation, lấy danh sách, lấy tin nhắn.
    /// Real-time messaging qua SignalR Hub tại /hubs/chat.
    /// </summary>
    [ApiController]
    [Route("api/conversations")]
    [Authorize]
    [Tags("Chat")]
    public class ConversationsApiController : ControllerBase
    {
        private readonly IConversationService _conversationService;

        public ConversationsApiController(IConversationService conversationService)
        {
            _conversationService = conversationService;
        }

        /// <summary>
        /// Lấy danh sách hội thoại của user hiện tại.
        /// </summary>
        /// <returns>Danh sách conversations với tin nhắn cuối cùng</returns>
        /// <response code="200">Trả về danh sách conversations</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpGet]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetConversations()
        {
            try
            {
                long userId = GetCurrentUserId();
                var result = await _conversationService.GetConversationsAsync(userId);
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Tạo hoặc lấy conversation đã tồn tại giữa tenant và landlord cho một tin đăng.
        /// </summary>
        /// <param name="dto">LandlordId và ListingId</param>
        /// <returns>Conversation (mới tạo hoặc đã tồn tại)</returns>
        /// <response code="200">Trả về conversation</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpPost]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> CreateConversation([FromBody] CreateConversationDto dto)
        {
            try
            {
                long tenantId = GetCurrentUserId();
                var result = await _conversationService.GetOrCreateConversationAsync(tenantId, dto.LandlordId, dto.ListingId);
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy lịch sử tin nhắn của một conversation (phân trang).
        /// </summary>
        /// <param name="id">ID của conversation</param>
        /// <param name="page">Trang (mặc định 1)</param>
        /// <returns>Danh sách tin nhắn</returns>
        /// <response code="200">Trả về danh sách tin nhắn</response>
        /// <response code="401">Chưa đăng nhập</response>
        [HttpGet("{id:long}/messages")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMessages(long id, [FromQuery] int page = 1)
        {
            try
            {
                long userId = GetCurrentUserId();
                var result = await _conversationService.GetMessagesAsync(id, userId, page);
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [HttpPost("{id:long}/messages")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> SendMessage(long id, [FromBody] SendMessageDto dto)
        {
            try
            {
                long userId = GetCurrentUserId();
                dto.ConvId = id;
                var result = await _conversationService.SendMessageAsync(userId, dto);
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

        [HttpPut("{id:long}/read")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> MarkAsRead(long id)
        {
            try
            {
                long userId = GetCurrentUserId();
                await _conversationService.MarkAsReadAsync(id, userId);
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

        private long GetCurrentUserId()
        {
            var claim = User.FindFirst(ClaimTypes.NameIdentifier);
            if (claim == null || !long.TryParse(claim.Value, out long userId))
                throw new UnauthorizedAccessException();
            return userId;
        }
    }
}
