using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingPostPackage
{
    public long LppId { get; set; }

    public long ListingId { get; set; }

    public int PackageId { get; set; }

    public long? PaymentId { get; set; }

    public DateTime StartDate { get; set; }

    public DateTime EndDate { get; set; }

    public bool? IsActive { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Listing Listing { get; set; } = null!;

    public virtual PostPackage Package { get; set; } = null!;

    public virtual Payment? Payment { get; set; }
}
