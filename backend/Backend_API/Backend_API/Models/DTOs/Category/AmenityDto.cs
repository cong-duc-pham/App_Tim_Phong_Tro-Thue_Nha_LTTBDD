namespace Backend_API.Models.DTOs.Category
{
    public class AmenityDto
    {
        public int AmenityId { get; set; }
        public string Name { get; set; } = null!;
        public string? IconUrl { get; set; }
    }
}
