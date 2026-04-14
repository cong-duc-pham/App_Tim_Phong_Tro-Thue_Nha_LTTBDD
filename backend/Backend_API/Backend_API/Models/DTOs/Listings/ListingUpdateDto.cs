using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Listings
{
    /// <summary>
    /// DTO cập nhật tin đăng — chỉ chứa các field được phép thay đổi sau khi đăng.
    /// </summary>
    public class ListingUpdateDto
    {
        [MaxLength(200)]
        public string? Title { get; set; }

        public string? Description { get; set; }

        [Range(0, double.MaxValue)]
        public decimal? Price { get; set; }

        [Range(1, double.MaxValue)]
        public decimal? Area { get; set; }

        public int? TypeId { get; set; }
        public int? WardId { get; set; }
        public int? DistrictId { get; set; }
        public int? ProvinceId { get; set; }
        public string? StreetAddress { get; set; }
        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        // Ảnh — null nghĩa là giữ nguyên, chuỗi rỗng nghĩa là xóa slot đó
        public string? Image0 { get; set; }
        public string? Image1 { get; set; }
        public string? Image2 { get; set; }
        public string? Image3 { get; set; }
        public string? Image4 { get; set; }
        public string? Image5 { get; set; }

        public List<int>? AmenityIds { get; set; }

        public decimal? ElectricPrice { get; set; }
        public decimal? WaterPrice { get; set; }
        public decimal? InternetPrice { get; set; }
        public decimal? ParkingPrice { get; set; }

        public int? Floor { get; set; }
        public int? TotalFloors { get; set; }
        public int? MaxOccupants { get; set; }
        public bool? AllowPet { get; set; }
        public DateOnly? AvailableFrom { get; set; }
    }
}
