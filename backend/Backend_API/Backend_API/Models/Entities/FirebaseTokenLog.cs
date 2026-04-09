using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class FirebaseTokenLog
{
    public long LogId { get; set; }

    public long UserId { get; set; }

    public long? DeviceId { get; set; }

    public string? OldToken { get; set; }

    public string NewToken { get; set; } = null!;

    public string? ChangeReason { get; set; }

    public string? DeviceType { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual UserDevice? Device { get; set; }

    public virtual User User { get; set; } = null!;
}
