using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Invoice
{
    public long InvoiceId { get; set; }

    public long LandlordId { get; set; }

    public long? ListingId { get; set; }

    public string InvoiceCode { get; set; } = null!;

    public string InvoiceType { get; set; } = null!;

    public decimal TotalAmount { get; set; }

    public DateOnly DueDate { get; set; }

    public string? Note { get; set; }

    public int StatusId { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual User Landlord { get; set; } = null!;

    public virtual Listing? Listing { get; set; }

    public virtual ICollection<Payment> Payments { get; set; } = new List<Payment>();

    public virtual PaymentStatus Status { get; set; } = null!;
}
