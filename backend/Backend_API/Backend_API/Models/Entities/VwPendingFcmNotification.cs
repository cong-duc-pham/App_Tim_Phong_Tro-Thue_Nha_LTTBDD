using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class VwPendingFcmNotification
{
    public long NotifId { get; set; }

    public long UserId { get; set; }

    public string Title { get; set; } = null!;

    public string? Body { get; set; }

    public string? NotifType { get; set; }

    public long? RefId { get; set; }

    public string? RefType { get; set; }

    public DateTime? SentAt { get; set; }

    public string DeviceToken { get; set; } = null!;

    public string DeviceType { get; set; } = null!;

    public long DeviceId { get; set; }
}
