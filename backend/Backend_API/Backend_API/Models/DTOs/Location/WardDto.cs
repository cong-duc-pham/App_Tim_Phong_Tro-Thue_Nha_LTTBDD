namespace Backend_API.Models.DTOs.Location
{
    public class WardDto
    {
        public int WardId { get; set; }
        public string? WardCode { get; set; }
        public string WardName { get; set; } = null!;
        public int DistrictId { get; set; }
    }
}
