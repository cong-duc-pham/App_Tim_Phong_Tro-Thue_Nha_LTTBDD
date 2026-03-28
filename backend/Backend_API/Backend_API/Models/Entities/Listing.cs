namespace Backend_API.Models.Entities;

public class ListingStatus
{
    public int StatusId { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public ICollection<Listing> Listings { get; set; } = new List<Listing>();
}

public class Listing
{
    public long ListingId { get; set; }
    public long LandlordId { get; set; }
    public int TypeId { get; set; }
    public int StatusId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public decimal Area { get; set; }
    public int? Floor { get; set; }
    public int? TotalFloors { get; set; }
    public int MaxOccupants { get; set; } = 1;

    // Địa chỉ
    public int? ProvinceId { get; set; }
    public int? DistrictId { get; set; }
    public int? WardId { get; set; }
    public string StreetAddress { get; set; } = string.Empty;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }

    // Trạng thái & nhãn
    public bool IsVerified { get; set; } = false;
    public bool IsFeatured { get; set; } = false;
    public bool IsNew { get; set; } = true;
    public bool AllowPet { get; set; } = false;

    // Chi phí dịch vụ
    public decimal? ElectricPrice { get; set; }
    public decimal? WaterPrice { get; set; }
    public decimal? InternetPrice { get; set; }
    public decimal? ParkingPrice { get; set; }

    // Thống kê
    public int ViewCount { get; set; } = 0;
    public int SaveCount { get; set; } = 0;

    // Thời hạn
    public DateTime? AvailableFrom { get; set; }
    public DateTime? ExpiredAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    // Navigation
    public User Landlord { get; set; } = null!;
    public RoomType RoomType { get; set; } = null!;
    public ListingStatus Status { get; set; } = null!;
    public Province? Province { get; set; }
    public District? District { get; set; }
    public Ward? Ward { get; set; }
    public ICollection<ListingImage> Images { get; set; } = new List<ListingImage>();
    public ICollection<ListingAmenity> Amenities { get; set; } = new List<ListingAmenity>();
    public ICollection<Review> Reviews { get; set; } = new List<Review>();
}

public class ListingImage
{
    public long ImageId { get; set; }
    public long ListingId { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public bool IsCover { get; set; } = false;
    public int SortOrder { get; set; } = 0;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Listing Listing { get; set; } = null!;
}

public class ListingAmenity
{
    public long Id { get; set; }
    public long ListingId { get; set; }
    public int AmenityId { get; set; }
    public Listing Listing { get; set; } = null!;
    public Amenity Amenity { get; set; } = null!;
}

public class Favorite
{
    public long FavoriteId { get; set; }
    public long UserId { get; set; }
    public long ListingId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public User User { get; set; } = null!;
    public Listing Listing { get; set; } = null!;
}
