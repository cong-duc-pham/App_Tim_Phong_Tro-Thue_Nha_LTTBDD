namespace Backend_API.Models.Entities;

public class Notification
{
    public long NotifId { get; set; }
    public long UserId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Body { get; set; }
    public string? NotifType { get; set; }
    public long? RefId { get; set; }
    public string? RefType { get; set; }
    public bool IsRead { get; set; } = false;
    public DateTime SentAt { get; set; } = DateTime.UtcNow;

    public User User { get; set; } = null!;
}
