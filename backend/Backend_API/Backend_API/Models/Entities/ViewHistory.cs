using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ViewHistory
{
    public long ViewId { get; set; }

    public long UserId { get; set; }

    public long ListingId { get; set; }

    public DateTime? ViewedAt { get; set; }

    public int? DurationSec { get; set; }

    public virtual Listing Listing { get; set; } = null!;

    public virtual User User { get; set; } = null!;
}
