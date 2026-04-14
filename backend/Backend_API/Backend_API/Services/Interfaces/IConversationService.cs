using Backend_API.Models.DTOs.Chat;

namespace Backend_API.Services.Interfaces
{
    public interface IConversationService
    {
        Task<List<ConversationDto>> GetConversationsAsync(long userId);
        Task<List<MessageDto>> GetMessagesAsync(long convId, long userId, int page = 1, int pageSize = 50);
        Task<ConversationDto> GetOrCreateConversationAsync(long senderId, long landlordId, long listingId);
        
        // Cần cho ChatHub
        Task<MessageDto> SendMessageAsync(long senderId, SendMessageDto dto);
        Task<int> MarkAsReadAsync(long convId, long userId);
    }
}
