using Backend_API.Models.DTOs.Ai;

namespace Backend_API.Services.Interfaces
{
    public interface IAiChatService
    {
        Task<AiChatResponseDto> ReplyAsync(
            AiChatRequestDto request,
            CancellationToken cancellationToken = default);
    }
}
