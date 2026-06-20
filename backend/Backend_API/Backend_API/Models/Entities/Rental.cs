using System;

namespace Backend_API.Models.Entities
{
    public partial class Rental
    {
        public long RentalId { get; set; }
        public long ListingId { get; set; }
        public long TenantId { get; set; }
        public long LandlordId { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public string Status { get; set; } = "active";
        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }

        public virtual Listing Listing { get; set; } = null!;
        public virtual User Tenant { get; set; } = null!;
        public virtual User Landlord { get; set; } = null!;
    }
}
