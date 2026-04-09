using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class UserDevice
{
    public long DeviceId { get; set; }

    public long UserId { get; set; }

    public string DeviceToken { get; set; } = null!;

    public string DeviceType { get; set; } = null!;

    public string? DeviceName { get; set; }

    public bool? IsActive { get; set; }

    public DateTime? LastActive { get; set; }

    public string? FcmLastError { get; set; }

    public DateTime? FcmErrorAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual ICollection<FirebaseTokenLog> FirebaseTokenLogs { get; set; } = new List<FirebaseTokenLog>();

    public virtual User User { get; set; } = null!;
}
