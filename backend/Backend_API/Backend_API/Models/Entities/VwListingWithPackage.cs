using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class VwListingWithPackage
{
    public long ListingId { get; set; }

    public string Title { get; set; } = null!;

    public decimal Price { get; set; }

    public decimal Area { get; set; }

    public string StreetAddress { get; set; } = null!;

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    public string? CoverImage { get; set; }

    public string? StorageFolder { get; set; }

    public int? ViewCount { get; set; }

    public int? SaveCount { get; set; }

    public string StatusName { get; set; } = null!;

    public string? PackageName { get; set; }

    public string? PackageType { get; set; }

    public string? BadgeType { get; set; }

    public bool? IsHighlighted { get; set; }

    public bool? AllowBanner { get; set; }

    public int? MaxImages { get; set; }

    public bool? HasAnalytics { get; set; }

    public DateTime? PackageExpiresAt { get; set; }

    public int? PackageDaysLeft { get; set; }

    public string LandlordName { get; set; } = null!;

    public string? LandlordPhone { get; set; }

    public string? LandlordFirebaseUid { get; set; }
}
