using Microsoft.AspNetCore.SignalR;
using Microsoft.AspNetCore.Authorization;
using Backend_API.Services.Interfaces;
using Backend_API.Models.DTOs.Chat;
using Backend_API.Models.Entities;
using System.Security.Claims;
using System.Collections.Concurrent;

namespace Backend_API.Hubs
{
    [Authorize]
    public class ChatHub : Hub
    {
        private readonly IConversationService _conversationService;
        private readonly INotificationService _notificationService;
        private readonly PhongTroDbContext _context;

        // In-memory connection mapping: UserId -> HashSet of ConnectionIds
        private static readonly ConcurrentDictionary<long, HashSet<string>> _userConnections = new();

        public ChatHub(IConversationService conversationService, INotificationService notificationService, PhongTroDbContext context)
        {
            _conversationService = conversationService;
            _notificationService = notificationService;
            _context = context;
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();
            if (userId > 0)
            {
                var connections = _userConnections.GetOrAdd(userId, _ => new HashSet<string>());
                lock (connections)
                {
                    connections.Add(Context.ConnectionId);
                }
                
                // Add to a SignalR group named after the UserId for easy direct messaging
                await Groups.AddToGroupAsync(Context.ConnectionId, userId.ToString());
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
            if (userId > 0 && _userConnections.TryGetValue(userId, out var connections))
            {
                lock (connections)
                {
                    connections.Remove(Context.ConnectionId);
                    if (connections.Count == 0)
                    {
                        _userConnections.TryRemove(userId, out _);
                    }
                }
            }

            await base.OnDisconnectedAsync(exception);
        }

        /// <summary>
        /// Gửi tin nhắn real-time
        /// </summary>
        public async Task SendMessage(long convId, string content, string msgType = "text", string? fileUrl = null)
        {
            var senderId = GetUserId();
            
            // 1. Lưu DB
            var dto = new SendMessageDto
            {
                ConvId = convId,
                Content = content,
                MsgType = msgType,
                FileUrl = fileUrl
            };
            
            var message = await _conversationService.SendMessageAsync(senderId, dto);

            // 2. Tìm người nhận
            var conv = await _context.Conversations.FindAsync(convId);
            if (conv == null) return;

            long receiverId = (conv.TenantId == senderId) ? conv.LandlordId : conv.TenantId;

            // 3. Kiểm tra ONLINE (SignalR)
            bool isReceiverOnline = _userConnections.ContainsKey(receiverId);

            if (isReceiverOnline)
            {
                // ONLINE: Gửi qua SignalR
                await Clients.Group(receiverId.ToString()).SendAsync("ReceiveMessage", message);
            }
            else
            {
                // OFFLINE: Gửi FCM + Lưu Notification record
                var sender = await _context.Users.FindAsync(senderId);
                string senderName = sender?.FullName ?? "Ai đó";
                
                await _notificationService.CreateAndSendAsync(
                    userId: receiverId,
                    title: $"Tin nhắn mới từ {senderName}",
                    body: content,
                    notifType: "chat",
                    refId: convId,
                    refType: "conversation"
                );
            }

            // Gửi lại confirm cho người gửi (cập nhật MessageId/SentAt)
            await Clients.Caller.SendAsync("MessageSent", message);
        }

        /// <summary>
        /// Đánh dấu là đã đọc
        /// </summary>
        public async Task MarkAsRead(long convId)
        {
            var userId = GetUserId();
            await _conversationService.MarkAsReadAsync(convId, userId);
            
            // Thông báo cho người kia biết tin nhắn đã được đọc (nếu họ đang online)
            var conv = await _context.Conversations.FindAsync(convId);
            if (conv != null)
            {
                long otherUserId = (conv.TenantId == userId) ? conv.LandlordId : conv.TenantId;
                await Clients.Group(otherUserId.ToString()).SendAsync("MessagesRead", convId);
            }
        }

        private long GetUserId()
        {
            var claim = Context.User?.FindFirst(ClaimTypes.NameIdentifier);
            return claim != null && long.TryParse(claim.Value, out long userId) ? userId : 0;
        }
    }
}
