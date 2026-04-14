namespace Backend_API.Models.DTOs.Category
{
    public class RoomTypeDto
    {
        public int TypeId { get; set; }
        public string TypeName { get; set; } = null!;
        public string? IconUrl { get; set; }
    }
}
