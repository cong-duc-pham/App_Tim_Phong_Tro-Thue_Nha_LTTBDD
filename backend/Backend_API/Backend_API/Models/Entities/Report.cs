using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Report
{
    public long ReportId { get; set; }

    public long ReporterId { get; set; }

    public long? ListingId { get; set; }

    public long? UserId { get; set; }

    public string Reason { get; set; } = null!;

    public string? Description { get; set; }

    public string? Status { get; set; }

    public long? ResolvedBy { get; set; }

    public DateTime? ResolvedAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Listing? Listing { get; set; }

    public virtual User Reporter { get; set; } = null!;

    public virtual User? ResolvedByNavigation { get; set; }

    public virtual User? User { get; set; }
}
