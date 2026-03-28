namespace Backend_API.Models.Entities;

public class Amenity
{
    public int AmenityId { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? IconUrl { get; set; }
    public string? Category { get; set; }
    public bool IsActive { get; set; } = true;

    public ICollection<ListingAmenity> ListingAmenities { get; set; } = new List<ListingAmenity>();
}
