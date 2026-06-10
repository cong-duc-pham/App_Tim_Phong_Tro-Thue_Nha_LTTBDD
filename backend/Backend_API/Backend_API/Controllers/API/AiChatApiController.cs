using Backend_API.Models.DTOs.Ai;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers.API
{
    [ApiController]
    [Authorize]
    [Route("api/ai")]
    [Tags("AI Chat")]
    public class AiChatApiController : ControllerBase
    {
        private readonly IAiChatService _aiChatService;
        private readonly ILogger<AiChatApiController> _logger;

        public AiChatApiController(
            IAiChatService aiChatService,
            ILogger<AiChatApiController> logger)
        {
            _aiChatService = aiChatService;
            _logger = logger;
        }

        [HttpPost("chat")]
        [ProducesResponseType(typeof(AiChatResponseDto), StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(StatusCodes.Status503ServiceUnavailable)]
        public async Task<IActionResult> Chat(
            [FromBody] AiChatRequestDto request,
            CancellationToken cancellationToken)
        {
            try
            {
                return Ok(await _aiChatService.ReplyAsync(request, cancellationToken));
            }
            catch (Exception ex) when (ex is HttpRequestException
                                       || ex is TaskCanceledException
                                       || ex is InvalidOperationException)
            {
                _logger.LogWarning(ex, "AI chat request could not be completed.");
                return StatusCode(
                    StatusCodes.Status503ServiceUnavailable,
                    new { message = ex.Message });
            }
        }
    }
}
