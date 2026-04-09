using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Payment
{
    public long PaymentId { get; set; }

    public long InvoiceId { get; set; }

    public int MethodId { get; set; }

    public int StatusId { get; set; }

    public decimal Amount { get; set; }

    public string? TransactionRef { get; set; }

    public string? GatewayResponse { get; set; }

    public DateTime? PaidAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Invoice Invoice { get; set; } = null!;

    public virtual ICollection<ListingPostPackage> ListingPostPackages { get; set; } = new List<ListingPostPackage>();

    public virtual PaymentMethod Method { get; set; } = null!;

    public virtual PaymentStatus Status { get; set; } = null!;
}
