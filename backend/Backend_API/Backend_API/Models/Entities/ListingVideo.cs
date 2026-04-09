using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingVideo
{
    public long VideoId { get; set; }

    public long ListingId { get; set; }

    public string VideoUrl { get; set; } = null!;

    public string? StoragePath { get; set; }

    public string? Thumbnail { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Listing Listing { get; set; } = null!;
}
