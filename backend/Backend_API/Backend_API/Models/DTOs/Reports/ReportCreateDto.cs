using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Reports;

public class ReportCreateDto
{
    public long? ListingId { get; set; }

    public long? UserId { get; set; }

    [Required]
    [MaxLength(100)]
    public string Reason { get; set; } = string.Empty;

    public string? Description { get; set; }
}
