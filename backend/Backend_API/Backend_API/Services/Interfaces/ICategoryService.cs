using Backend_API.Models.DTOs.Category;

namespace Backend_API.Services.Interfaces
{
    public interface ICategoryService
    {
        Task<List<RoomTypeDto>> GetRoomTypesAsync();
        Task<List<AmenityDto>> GetAmenitiesAsync();
    }
}
