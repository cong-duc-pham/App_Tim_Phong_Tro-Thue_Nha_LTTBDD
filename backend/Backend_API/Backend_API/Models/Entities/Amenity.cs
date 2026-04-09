using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Amenity
{
    public int AmenityId { get; set; }

    public string Name { get; set; } = null!;

    public string? IconUrl { get; set; }

    public string? Category { get; set; }

    public bool? IsActive { get; set; }

    public virtual ICollection<ListingAmenity> ListingAmenities { get; set; } = new List<ListingAmenity>();

    public virtual ICollection<UserPreferenceAmenity> UserPreferenceAmenities { get; set; } = new List<UserPreferenceAmenity>();
}
