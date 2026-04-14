using Backend_API.Models.DTOs.Location;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class LocationService : ILocationService
    {
        private readonly PhongTroDbContext _context;

        public LocationService(PhongTroDbContext context)
        {
            _context = context;
        }

        public async Task<List<ProvinceDto>> GetProvincesAsync()
        {
            return await _context.Provinces
                .OrderBy(p => p.ProvinceName)
                .Select(p => new ProvinceDto
                {
                    ProvinceId = p.ProvinceId,
                    ProvinceCode = p.ProvinceCode,
                    ProvinceName = p.ProvinceName
                })
                .ToListAsync();
        }

        public async Task<List<DistrictDto>> GetDistrictsByProvinceAsync(int provinceId)
        {
            return await _context.Districts
                .Where(d => d.ProvinceId == provinceId)
                .OrderBy(d => d.DistrictName)
                .Select(d => new DistrictDto
                {
                    DistrictId = d.DistrictId,
                    DistrictCode = d.DistrictCode,
                    DistrictName = d.DistrictName,
                    ProvinceId = d.ProvinceId
                })
                .ToListAsync();
        }

        public async Task<List<WardDto>> GetWardsByDistrictAsync(int districtId)
        {
            return await _context.Wards
                .Where(w => w.DistrictId == districtId)
                .OrderBy(w => w.WardName)
                .Select(w => new WardDto
                {
                    WardId = w.WardId,
                    WardCode = w.WardCode,
                    WardName = w.WardName,
                    DistrictId = w.DistrictId
                })
                .ToListAsync();
        }
    }
}
