using System;

namespace Backend_API.Models.DTOs.Rentals
{
    public class RentalCreateDto
    {
        public string TenantPhone { get; set; } = null!;
        public DateTime? StartDate { get; set; }
        public DateTime? EndDate { get; set; }
    }
}
