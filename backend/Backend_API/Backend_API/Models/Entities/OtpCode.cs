namespace Backend_API.Models.Entities;

public class OtpCode
{
    public long OtpId { get; set; }
    public long? UserId { get; set; }
    public string Contact { get; set; } = string.Empty;  // email hoặc phone
    public string OtpType { get; set; } = string.Empty;  // register | forgot_password | verify
    public string Code { get; set; } = string.Empty;
    public bool IsUsed { get; set; } = false;
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public User? User { get; set; }
}
