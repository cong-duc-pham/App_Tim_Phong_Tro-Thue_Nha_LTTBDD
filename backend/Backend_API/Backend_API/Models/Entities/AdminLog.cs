using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class AdminLog
{
    public long LogId { get; set; }

    public long AdminId { get; set; }

    public string Action { get; set; } = null!;

    public string? TargetType { get; set; }

    public long? TargetId { get; set; }

    public string? Detail { get; set; }

    public string? IpAddress { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual User Admin { get; set; } = null!;
}
