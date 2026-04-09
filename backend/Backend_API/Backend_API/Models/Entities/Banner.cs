using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Banner
{
    public int BannerId { get; set; }

    public string? Title { get; set; }

    public string ImageUrl { get; set; } = null!;

    public string? StoragePath { get; set; }

    public string? LinkUrl { get; set; }

    public long? ListingId { get; set; }

    public int? SortOrder { get; set; }

    public bool? IsActive { get; set; }

    public DateTime? StartDate { get; set; }

    public DateTime? EndDate { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Listing? Listing { get; set; }
}
