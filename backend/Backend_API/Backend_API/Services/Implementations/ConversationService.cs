using Backend_API.Models.DTOs.Chat;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class ConversationService : IConversationService
    {
        private readonly PhongTroDbContext _context;

        public ConversationService(PhongTroDbContext context)
        {
            _context = context;
        }

        public async Task<List<ConversationDto>> GetConversationsAsync(long userId)
        {
            var conversations = await _context.Conversations
                .Include(c => c.Listing)
                .Include(c => c.Tenant)
                .Include(c => c.Landlord)
                .Include(c => c.Messages)
                .Where(c => c.TenantId == userId || c.LandlordId == userId)
                .OrderByDescending(c => c.LastMsgAt)
                .ToListAsync();

            return conversations.Select(c => {
                var otherUser = c.TenantId == userId ? c.Landlord : c.Tenant;
                var lastMsg = c.Messages.OrderByDescending(m => m.SentAt).FirstOrDefault();
                
                return new ConversationDto
                {
                    ConvId = c.ConvId,
                    ListingId = c.ListingId,
                    ListingTitle = c.Listing?.Title,
                    ListingImage = c.Listing?.Image0,
                    TenantId = c.TenantId,
                    LandlordId = c.LandlordId,
                    LastMessage = lastMsg?.Content,
                    LastMsgAt = c.LastMsgAt,
                    OtherUserId = otherUser.UserId,
                    OtherUserName = otherUser.FullName ?? "User",
                    OtherUserAvatar = otherUser.AvatarUrl,
                    UnreadCount = c.Messages.Count(m => m.SenderId != userId && (m.IsRead == false || m.IsRead == null))
                };
            }).ToList();
        }

        public async Task<List<MessageDto>> GetMessagesAsync(long convId, long userId, int page = 1, int pageSize = 50)
        {
            var conv = await _context.Conversations.FindAsync(convId);
            if (conv == null || (conv.TenantId != userId && conv.LandlordId != userId))
                return new List<MessageDto>();

            var messages = await _context.Messages
                .Where(m => m.ConvId == convId)
                .OrderByDescending(m => m.SentAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync();

            return messages.Select(m => new MessageDto
            {
                MessageId = m.MessageId,
                ConvId = m.ConvId,
                SenderId = m.SenderId,
                Content = m.Content,
                MsgType = m.MsgType,
                FileUrl = m.FileUrl,
                IsRead = m.IsRead ?? false,
                SentAt = m.SentAt
            }).Reverse().ToList(); 
        }

        public async Task<ConversationDto> GetOrCreateConversationAsync(long senderId, long landlordId, long listingId)
        {
            if (senderId == landlordId)
                throw new Exception("Bạn không thể nhắn tin với chính mình.");

            var conv = await _context.Conversations
                .FirstOrDefaultAsync(c => c.ListingId == listingId && c.TenantId == senderId && c.LandlordId == landlordId);

            if (conv == null)
            {
                conv = new Conversation
                {
                    ListingId = listingId,
                    TenantId = senderId,
                    LandlordId = landlordId,
                    CreatedAt = DateTime.UtcNow,
                    LastMsgAt = DateTime.UtcNow
                };
                await _context.Conversations.AddAsync(conv);
                await _context.SaveChangesAsync();
            }

            return (await GetConversationsAsync(senderId)).First(c => c.ConvId == conv.ConvId);
        }

        public async Task<MessageDto> SendMessageAsync(long senderId, SendMessageDto dto)
        {
            var conv = await _context.Conversations.FindAsync(dto.ConvId)
                ?? throw new Exception("Không tìm thấy cuộc trò chuyện.");
            if (conv.TenantId != senderId && conv.LandlordId != senderId)
                throw new Exception("Bạn không phải là thành viên của cuộc trò chuyện này.");

            var message = new Message
            {
                ConvId = dto.ConvId,
                SenderId = senderId,
                Content = dto.Content,
                MsgType = dto.MsgType,
                FileUrl = dto.FileUrl,
                IsRead = false,
                SentAt = DateTime.UtcNow
            };

            await _context.Messages.AddAsync(message);
            conv.LastMsgAt = message.SentAt;
            await _context.SaveChangesAsync();

            return new MessageDto
            {
                MessageId = message.MessageId,
                ConvId = message.ConvId,
                SenderId = message.SenderId,
                Content = message.Content,
                MsgType = message.MsgType,
                FileUrl = message.FileUrl,
                IsRead = false,
                SentAt = message.SentAt
            };
        }

        public async Task<int> MarkAsReadAsync(long convId, long userId)
        {
            var unreadMessages = await _context.Messages
                .Where(m => m.ConvId == convId && m.SenderId != userId && (m.IsRead == false || m.IsRead == null))
                .ToListAsync();

            foreach (var m in unreadMessages)
            {
                m.IsRead = true;
            }

            return await _context.SaveChangesAsync();
        }
    }
}
