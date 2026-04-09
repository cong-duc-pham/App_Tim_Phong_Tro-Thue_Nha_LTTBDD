using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Ward
{
    public int WardId { get; set; }

    public int DistrictId { get; set; }

    public string WardName { get; set; } = null!;

    public string? WardCode { get; set; }

    public virtual District District { get; set; } = null!;

    public virtual ICollection<Listing> Listings { get; set; } = new List<Listing>();
}
