using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Province
{
    public int ProvinceId { get; set; }

    public string ProvinceName { get; set; } = null!;

    public string? ProvinceCode { get; set; }

    public virtual ICollection<District> Districts { get; set; } = new List<District>();

    public virtual ICollection<Listing> Listings { get; set; } = new List<Listing>();
}
