namespace Backend_API.Models.Entities;

public class RoomType
{
    public int TypeId { get; set; }
    public string TypeName { get; set; } = string.Empty;
    public string? IconUrl { get; set; }
    public int SortOrder { get; set; } = 0;
    public bool IsActive { get; set; } = true;

    public ICollection<Listing> Listings { get; set; } = new List<Listing>();
}
