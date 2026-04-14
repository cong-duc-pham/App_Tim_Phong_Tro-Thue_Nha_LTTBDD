using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Listing
{
    public long ListingId { get; set; }

    public long LandlordId { get; set; }

    public int TypeId { get; set; }

    public int StatusId { get; set; }

    public string Title { get; set; } = null!;

    public string? Description { get; set; }

    public decimal Price { get; set; }

    public decimal Area { get; set; }

    public int? Floor { get; set; }

    public int? TotalFloors { get; set; }

    public int? MaxOccupants { get; set; }

    public int? ProvinceId { get; set; }

    public int? DistrictId { get; set; }

    public int? WardId { get; set; }

    public string StreetAddress { get; set; } = null!;

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    public bool? IsVerified { get; set; }

    public bool? IsFeatured { get; set; }

    public bool? IsNew { get; set; }

    public bool? AllowPet { get; set; }

    public string? Image0 { get; set; }

    public string? Image1 { get; set; }

    public string? Image2 { get; set; }

    public string? Image3 { get; set; }

    public string? Image4 { get; set; }

    public string? Image5 { get; set; }

    public string? CloudinaryFolder { get; set; }

    public decimal? ElectricPrice { get; set; }

    public decimal? WaterPrice { get; set; }

    public decimal? InternetPrice { get; set; }

    public decimal? ParkingPrice { get; set; }

    public int? ViewCount { get; set; }

    public int? SaveCount { get; set; }

    public DateOnly? AvailableFrom { get; set; }

    public DateTime? ExpiredAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual ICollection<Banner> Banners { get; set; } = new List<Banner>();

    public virtual ICollection<Conversation> Conversations { get; set; } = new List<Conversation>();

    public virtual District? District { get; set; }

    public virtual ICollection<Favorite> Favorites { get; set; } = new List<Favorite>();

    public virtual ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();

    public virtual User Landlord { get; set; } = null!;

    public virtual ICollection<ListingAmenity> ListingAmenities { get; set; } = new List<ListingAmenity>();

    public virtual ICollection<ListingImage> ListingImages { get; set; } = new List<ListingImage>();

    public virtual ICollection<ListingPostPackage> ListingPostPackages { get; set; } = new List<ListingPostPackage>();

    public virtual ICollection<ListingPriceHistory> ListingPriceHistories { get; set; } = new List<ListingPriceHistory>();

    public virtual ICollection<ListingVideo> ListingVideos { get; set; } = new List<ListingVideo>();

    public virtual Province? Province { get; set; }

    public virtual ICollection<Report> Reports { get; set; } = new List<Report>();

    public virtual ICollection<Review> Reviews { get; set; } = new List<Review>();

    public virtual ListingStatus Status { get; set; } = null!;

    public virtual RoomType Type { get; set; } = null!;

    public virtual ICollection<ViewHistory> ViewHistories { get; set; } = new List<ViewHistory>();

    public virtual Ward? Ward { get; set; }
}
