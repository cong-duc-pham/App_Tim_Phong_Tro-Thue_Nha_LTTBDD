namespace Backend_API.Models.DTOs.Location
{
    public class DistrictDto
    {
        public int DistrictId { get; set; }
        public string? DistrictCode { get; set; }
        public string DistrictName { get; set; } = null!;
        public int ProvinceId { get; set; }
    }
}
