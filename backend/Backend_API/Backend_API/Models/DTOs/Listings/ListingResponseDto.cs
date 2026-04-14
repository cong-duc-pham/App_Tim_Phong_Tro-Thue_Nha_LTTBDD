namespace Backend_API.Models.DTOs.Listings
{
    public class ListingResponseDto
    {
        // ── Thông tin cơ bản
        public long ListingId { get; set; }
        public long LandlordId { get; set; }
        public string LandlordName { get; set; } = null!;
        public string? LandlordAvatar { get; set; }
        public string LandlordPhone { get; set; } = null!;

        public string Title { get; set; } = null!;
        public string? Description { get; set; }
        public decimal Price { get; set; }
        public decimal Area { get; set; }

        // ── Loại phòng
        public int TypeId { get; set; }
        public string TypeName { get; set; } = null!;

        // ── Địa chỉ
        public int? ProvinceId { get; set; }
        public string? ProvinceName { get; set; }
        public int? DistrictId { get; set; }
        public string? DistrictName { get; set; }
        public int? WardId { get; set; }
        public string? WardName { get; set; }
        public string StreetAddress { get; set; } = null!;
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        // ── Ảnh (Cloudinary URLs)
        public string? Image0 { get; set; }
        public string? Image1 { get; set; }
        public string? Image2 { get; set; }
        public string? Image3 { get; set; }
        public string? Image4 { get; set; }
        public string? Image5 { get; set; }

        // ── Giá dịch vụ
        public decimal? ElectricPrice { get; set; }
        public decimal? WaterPrice { get; set; }
        public decimal? InternetPrice { get; set; }
        public decimal? ParkingPrice { get; set; }

        // ── Thông tin thêm
        public int? Floor { get; set; }
        public int? TotalFloors { get; set; }
        public int? MaxOccupants { get; set; }
        public bool? AllowPet { get; set; }
        public DateOnly? AvailableFrom { get; set; }

        // ── Tiện ích
        public List<string> AmenityNames { get; set; } = new();

        // ── Trạng thái & thống kê
        public string StatusName { get; set; } = null!;
        public bool? IsVerified { get; set; }
        public bool? IsFeatured { get; set; }
        public int? ViewCount { get; set; }
        public int? SaveCount { get; set; }

        // ── Đánh giá trung bình
        public double AverageRating { get; set; }
        public int ReviewCount { get; set; }

        // ── Gói tin VIP đang kích hoạt (nếu có)
        public PackageInfoDto? PackageInfo { get; set; }

        public DateTime? CreatedAt { get; set; }
        public DateTime? ExpiredAt { get; set; }
    }

    public class PackageInfoDto
    {
        public string PackageName { get; set; } = null!;
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public bool IsActive { get; set; }
    }
}
