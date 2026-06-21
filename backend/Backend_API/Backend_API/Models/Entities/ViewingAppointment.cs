using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ViewingAppointment
{
    public long AppointmentId { get; set; }

    public long ListingId { get; set; }

    public long TenantId { get; set; }

    public long LandlordId { get; set; }

    public DateTime ScheduledAt { get; set; }

    public string Status { get; set; } = null!;

    public string? TenantNote { get; set; }

    public string? LandlordNote { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual Listing Listing { get; set; } = null!;

    public virtual User Landlord { get; set; } = null!;

    public virtual User Tenant { get; set; } = null!;
}
