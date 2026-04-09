using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingImage
{
    public long ImageId { get; set; }

    public long ListingId { get; set; }

    public string ImageUrl { get; set; } = null!;

    public string? StoragePath { get; set; }

    public bool? IsCover { get; set; }

    public int? SortOrder { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Listing Listing { get; set; } = null!;
}
