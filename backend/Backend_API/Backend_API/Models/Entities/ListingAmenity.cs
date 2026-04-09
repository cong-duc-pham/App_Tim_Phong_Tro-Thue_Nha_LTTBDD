using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingAmenity
{
    public long Id { get; set; }

    public long ListingId { get; set; }

    public int AmenityId { get; set; }

    public virtual Amenity Amenity { get; set; } = null!;

    public virtual Listing Listing { get; set; } = null!;
}
