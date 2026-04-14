using Backend_API.Models.DTOs.Notifications;

namespace Backend_API.Services.Interfaces
{
    public interface INotificationService
    {
        /// <summary>
        /// Tạo 1 thông báo lưu vào DB và gửi Push Notification qua Firebase.
        /// </summary>
        Task<bool> CreateAndSendAsync(long userId, string title, string body, string notifType, long? refId = null, string? refType = null);

        /// <summary>
        /// Lấy danh sách thông báo của user (mới nhất lên đầu).
        /// </summary>
        Task<List<NotificationDto>> GetNotificationsAsync(long userId);

        /// <summary>
        /// Đánh dấu thông báo là đã đọc.
        /// </summary>
        Task MarkAsReadAsync(long notifId, long userId);

        /// <summary>
        /// Lấy số lượng thông báo chưa đọc của user.
        /// </summary>
        Task<int> GetUnreadCountAsync(long userId);
    }
}
