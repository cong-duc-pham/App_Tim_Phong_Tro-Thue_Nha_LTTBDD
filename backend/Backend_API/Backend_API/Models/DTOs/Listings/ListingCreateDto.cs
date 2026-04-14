using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Listings
{
    public class ListingCreateDto
    {
        [Required]
        [MaxLength(200)]
        public string Title { get; set; } = null!;

        public string? Description { get; set; }

        [Required]
        [Range(0, double.MaxValue)]
        public decimal Price { get; set; }

        [Required]
        [Range(1, double.MaxValue)]
        public decimal Area { get; set; }

        [Required]
        public int TypeId { get; set; }

        public int? ProvinceId { get; set; }
        public int? DistrictId { get; set; }
        public int? WardId { get; set; }

        [Required]
        public string StreetAddress { get; set; } = null!;

        public double? Latitude { get; set; }
        public double? Longitude { get; set; }

        // Ảnh lưu dưới dạng Firebase Storage URL (Flutter upload xong gửi URL lên)
        public string? Image0 { get; set; }
        public string? Image1 { get; set; }
        public string? Image2 { get; set; }
        public string? Image3 { get; set; }
        public string? Image4 { get; set; }
        public string? Image5 { get; set; }

        // Thư mục chứa ảnh trên Cloudinary (để xóa khi cần)
        public string? CloudinaryFolder { get; set; }

        // Tiện ích đi kèm
        public List<int> AmenityIds { get; set; } = new();

        // Giá dịch vụ
        public decimal? ElectricPrice { get; set; }
        public decimal? WaterPrice { get; set; }
        public decimal? InternetPrice { get; set; }
        public decimal? ParkingPrice { get; set; }

        // Thông tin thêm
        public int? Floor { get; set; }
        public int? TotalFloors { get; set; }
        public int? MaxOccupants { get; set; }
        public bool? AllowPet { get; set; }
        public DateOnly? AvailableFrom { get; set; }
    }
}
