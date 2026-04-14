using Backend_API.Models.DTOs.Category;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class CategoryService : ICategoryService
    {
        private readonly PhongTroDbContext _context;

        public CategoryService(PhongTroDbContext context)
        {
            _context = context;
        }

        public async Task<List<RoomTypeDto>> GetRoomTypesAsync()
        {
            return await _context.RoomTypes
                .Where(r => r.IsActive == true)
                .OrderBy(r => r.SortOrder)
                .Select(r => new RoomTypeDto
                {
                    TypeId = r.TypeId,
                    TypeName = r.TypeName,
                    IconUrl = r.IconUrl
                })
                .ToListAsync();
        }

        public async Task<List<AmenityDto>> GetAmenitiesAsync()
        {
            return await _context.Amenities
                .Where(a => a.IsActive == true)
                .OrderBy(a => a.Name)
                .Select(a => new AmenityDto
                {
                    AmenityId = a.AmenityId,
                    Name = a.Name,
                    IconUrl = a.IconUrl
                })
                .ToListAsync();
        }
    }
}
