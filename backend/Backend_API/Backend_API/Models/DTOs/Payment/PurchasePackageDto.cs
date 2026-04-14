using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Payment
{
    public class PurchasePackageDto
    {
        [Required]
        [Range(1, long.MaxValue)]
        public long ListingId { get; set; }

        [Required]
        [Range(1, int.MaxValue)]
        public int PackageId { get; set; }
    }
}
