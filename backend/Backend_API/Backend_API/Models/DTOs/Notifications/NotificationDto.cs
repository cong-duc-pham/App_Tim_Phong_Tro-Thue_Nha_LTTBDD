namespace Backend_API.Models.DTOs.Notifications
{
    public class NotificationDto
    {
        public long NotifId { get; set; }
        public long UserId { get; set; }
        public string Title { get; set; } = null!;
        public string? Body { get; set; }
        public string? NotifType { get; set; }
        public long? RefId { get; set; }
        public string? RefType { get; set; }
        public bool IsRead { get; set; }
        public DateTime? SentAt { get; set; }
    }
}
