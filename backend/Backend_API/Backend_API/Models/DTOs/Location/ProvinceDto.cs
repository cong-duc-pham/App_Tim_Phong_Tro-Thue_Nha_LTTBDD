namespace Backend_API.Models.DTOs.Location
{
    public class ProvinceDto
    {
        public int ProvinceId { get; set; }
        public string? ProvinceCode { get; set; }
        public string ProvinceName { get; set; } = null!;
    }
}
