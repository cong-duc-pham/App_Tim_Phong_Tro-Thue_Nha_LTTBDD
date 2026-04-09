using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class UserPreferenceAmenity
{
    public long Id { get; set; }

    public long PrefId { get; set; }

    public int AmenityId { get; set; }

    public virtual Amenity Amenity { get; set; } = null!;

    public virtual UserPreference Pref { get; set; } = null!;
}
