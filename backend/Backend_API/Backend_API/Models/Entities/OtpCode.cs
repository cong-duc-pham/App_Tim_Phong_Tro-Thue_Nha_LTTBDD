using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class OtpCode
{
    public long OtpId { get; set; }

    public long? UserId { get; set; }

    public string Contact { get; set; } = null!;

    public string OtpType { get; set; } = null!;

    public string Code { get; set; } = null!;

    public bool? IsUsed { get; set; }

    public DateTime ExpiresAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual User? User { get; set; }
}
