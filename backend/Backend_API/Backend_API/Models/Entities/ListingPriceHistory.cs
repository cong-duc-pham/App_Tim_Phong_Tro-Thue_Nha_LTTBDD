using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingPriceHistory
{
    public long HistoryId { get; set; }

    public long ListingId { get; set; }

    public decimal OldPrice { get; set; }

    public decimal NewPrice { get; set; }

    public DateTime? ChangedAt { get; set; }

    public virtual Listing Listing { get; set; } = null!;
}
