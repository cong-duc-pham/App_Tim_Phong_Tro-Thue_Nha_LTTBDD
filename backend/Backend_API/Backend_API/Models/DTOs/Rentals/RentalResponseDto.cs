using System;

namespace Backend_API.Models.DTOs.Rentals
{
    public class RentalResponseDto
    {
        public long RentalId { get; set; }
        public long ListingId { get; set; }
        public string ListingTitle { get; set; } = null!;
        public string? ListingAddress { get; set; }
        public string? ListingThumbnail { get; set; }
        public long TenantId { get; set; }
        public string TenantName { get; set; } = null!;
        public string? TenantPhone { get; set; }
        public string? TenantAvatar { get; set; }
        public long LandlordId { get; set; }
        public string LandlordName { get; set; } = null!;
        public DateTime StartDate { get; set; }
        public DateTime? EndDate { get; set; }
        public string Status { get; set; } = null!;
        public DateTime? CreatedAt { get; set; }
    }
}
