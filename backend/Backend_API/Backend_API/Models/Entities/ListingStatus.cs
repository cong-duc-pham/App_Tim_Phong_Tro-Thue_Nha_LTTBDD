using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingStatus
{
    public int StatusId { get; set; }

    public string StatusName { get; set; } = null!;

    public virtual ICollection<Listing> Listings { get; set; } = new List<Listing>();
}
