using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class PostPackage
{
    public int PackageId { get; set; }

    public string PackageName { get; set; } = null!;

    public string PackageType { get; set; } = null!;

    public int DurationDays { get; set; }

    public decimal Price { get; set; }

    public int Priority { get; set; }

    public int MaxImages { get; set; }

    public int MaxVideos { get; set; }

    public bool AllowBanner { get; set; }

    public string? BadgeType { get; set; }

    public bool HasAnalytics { get; set; }

    public bool IsHighlighted { get; set; }

    public string? Description { get; set; }

    public bool IsActive { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual ICollection<ListingPostPackage> ListingPostPackages { get; set; } = new List<ListingPostPackage>();
}
