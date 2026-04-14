using Backend_API.Helpers;
using Backend_API.Models.DTOs.Notifications;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Data.Common;

namespace Backend_API.Services.Implementations
{
    public class NotificationService : INotificationService
    {
        private readonly PhongTroDbContext _context;
        private readonly FirebaseMessagingHelper _fcmHelper;

        public NotificationService(PhongTroDbContext context, FirebaseMessagingHelper fcmHelper)
        {
            _context = context;
            _fcmHelper = fcmHelper;
        }

        public async Task<bool> CreateAndSendAsync(long userId, string title, string body, string notifType, long? refId = null, string? refType = null)
        {
            // Bước 1: Insert Notifications
            var notif = new Notification
            {
                UserId = userId,
                Title = title,
                Body = body,
                NotifType = notifType,
                RefId = refId,
                RefType = refType,
                IsRead = false,
                FcmStatus = "pending",
                SentAt = DateTime.UtcNow
            };

            await _context.Notifications.AddAsync(notif);
            await _context.SaveChangesAsync();

            // Bước 2: Lấy Active FCM Tokens (Sử dụng DbCommand để gọi SP)
            var tokens = new List<string>();
            try
            {
                var conn = _context.Database.GetDbConnection();
                if (conn.State != System.Data.ConnectionState.Open)
                    await conn.OpenAsync();

                using var cmd = conn.CreateCommand();
                cmd.CommandText = "EXEC sp_GetActiveFcmTokens @UserId";
                
                var param = cmd.CreateParameter();
                param.ParameterName = "@UserId";
                param.Value = userId;
                cmd.Parameters.Add(param);

                using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                {
                    tokens.Add(reader.GetString(0));
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Notif] SP error, falling back to LINQ: {ex.Message}");
                // Fallback nếu SP không tồn tại hoặc lỗi
                tokens = await _context.UserDevices
                    .Where(d => d.UserId == userId && d.IsActive == true)
                    .Select(d => d.DeviceToken)
                    .ToListAsync();
            }

            // Nếu user không có thiết bị nào đang active -> bỏ qua push nhưng notification vẫn lưu ở DB
            if (tokens.Count == 0)
            {
                notif.FcmStatus = "no_device";
                await _context.SaveChangesAsync();
                return true; // Vẫn coi là thành công vì đã lưu DB
            }

            // Bước 3: Gọi FirebaseMessagingHelper
            var dataPayload = new Dictionary<string, string>
            {
                { "notifId", notif.NotifId.ToString() },
                { "notifType", notifType }
            };
            
            if (refId.HasValue) dataPayload.Add("refId", refId.Value.ToString());
            if (!string.IsNullOrEmpty(refType)) dataPayload.Add("refType", refType);

            bool isSuccess = await _fcmHelper.SendToMultipleAsync(tokens, title, body, dataPayload);

            // Bước 4: Cập nhật trạng thái sau khi gửi Firebase (Gọi sp_UpdateNotificationFcmStatus)
            try
            {
                string status = isSuccess ? "sent" : "failed";
                string errorMsg = isSuccess ? "" : "Firebase SDK returned false";
                
                // Gọi SP
                await _context.Database.ExecuteSqlRawAsync(
                    "EXEC sp_UpdateNotificationFcmStatus @p0, @p1, @p2", 
                    notif.NotifId, status, errorMsg);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[Notif] Update Status SP Error: {ex.Message}");
                // Fallback nếu SP lỗi
                notif.FcmStatus = isSuccess ? "sent" : "failed";
                notif.FcmSentAt = DateTime.UtcNow;
                if (!isSuccess) notif.FcmErrorMsg = "FCM push failed";
                await _context.SaveChangesAsync();
            }

            return isSuccess;
        }

        public async Task<List<NotificationDto>> GetNotificationsAsync(long userId)
        {
            var notifs = await _context.Notifications
                .Where(n => n.UserId == userId)
                .OrderByDescending(n => n.SentAt)
                .ToListAsync();

            return notifs.Select(n => new NotificationDto
            {
                NotifId = n.NotifId,
                UserId = n.UserId,
                Title = n.Title,
                Body = n.Body,
                NotifType = n.NotifType,
                RefId = n.RefId,
                RefType = n.RefType,
                IsRead = n.IsRead ?? false,
                SentAt = n.SentAt
            }).ToList();
        }

        public async Task MarkAsReadAsync(long notifId, long userId)
        {
            var notif = await _context.Notifications
                .FirstOrDefaultAsync(n => n.NotifId == notifId && n.UserId == userId);
            
            if (notif != null && notif.IsRead != true)
            {
                notif.IsRead = true;
                await _context.SaveChangesAsync();
            }
        }

        public async Task<int> GetUnreadCountAsync(long userId)
        {
            return await _context.Notifications
                .CountAsync(n => n.UserId == userId && n.IsRead == false);
        }
    }
}
