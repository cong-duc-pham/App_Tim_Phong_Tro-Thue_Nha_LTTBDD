using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Conversation
{
    public long ConvId { get; set; }

    public long? ListingId { get; set; }

    public long TenantId { get; set; }

    public long LandlordId { get; set; }

    public DateTime? LastMsgAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual User Landlord { get; set; } = null!;

    public virtual Listing? Listing { get; set; }

    public virtual ICollection<Message> Messages { get; set; } = new List<Message>();

    public virtual User Tenant { get; set; } = null!;
}
