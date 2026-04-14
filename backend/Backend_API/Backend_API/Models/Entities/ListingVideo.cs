using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingVideo
{
    public long VideoId { get; set; }

    public long ListingId { get; set; }

    public string CloudinaryUrl { get; set; } = null!;

    public string? CloudinaryPublicId { get; set; }

    public string? ThumbnailUrl { get; set; }

    public int? DurationSec { get; set; }

    public int? FileSizeKb { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Listing Listing { get; set; } = null!;
}
