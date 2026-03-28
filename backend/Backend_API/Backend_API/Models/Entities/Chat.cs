namespace Backend_API.Models.Entities;

public class Conversation
{
    public long ConvId { get; set; }
    public long? ListingId { get; set; }
    public long TenantId { get; set; }
    public long LandlordId { get; set; }
    public DateTime? LastMsgAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public Listing? Listing { get; set; }
    public User Tenant { get; set; } = null!;
    public User Landlord { get; set; } = null!;
    public ICollection<Message> Messages { get; set; } = new List<Message>();
}

public class Message
{
    public long MessageId { get; set; }
    public long ConvId { get; set; }
    public long SenderId { get; set; }
    public string? Content { get; set; }
    public string MsgType { get; set; } = "text";
    public string? FileUrl { get; set; }
    public bool IsRead { get; set; } = false;
    public DateTime SentAt { get; set; } = DateTime.UtcNow;

    public Conversation Conversation { get; set; } = null!;
    public User Sender { get; set; } = null!;
}
