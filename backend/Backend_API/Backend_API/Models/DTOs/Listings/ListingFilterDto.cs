namespace Backend_API.Models.DTOs.Listings
{
    public class ListingFilterDto
    {
        // ── Tìm kiếm theo từ khóa (tiêu đề, địa chỉ)
        public string? Keyword { get; set; }

        // ── Lọc giá
        public decimal? MinPrice { get; set; }
        public decimal? MaxPrice { get; set; }

        // ── Lọc diện tích
        public decimal? MinArea { get; set; }
        public decimal? MaxArea { get; set; }

        // ── Lọc địa lý theo đơn vị hành chính
        public int? ProvinceId { get; set; }
        public int? DistrictId { get; set; }
        public int? WardId { get; set; }

        // ── Lọc theo loại phòng
        public int? TypeId { get; set; }

        // ── Lọc theo vị trí địa lý & bán kính (km)
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }
        public double? RadiusKm { get; set; }

        // ── Lọc theo tiện ích (phải có TẤT CẢ amenity trong danh sách)
        public List<int>? AmenityIds { get; set; }

        // ── Các cờ lọc khác
        public bool? AllowPet { get; set; }
        public bool? IsVerified { get; set; }
        public bool? IsFeatured { get; set; }

        // ── Phân trang
        public int Page { get; set; } = 1;
        public int PageSize { get; set; } = 10;

        // ── Sắp xếp: "price_asc" | "price_desc" | "newest" | "rating" | "distance"
        public string SortBy { get; set; } = "newest";
    }
}
