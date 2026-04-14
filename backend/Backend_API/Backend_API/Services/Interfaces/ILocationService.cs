using Backend_API.Models.DTOs.Location;

namespace Backend_API.Services.Interfaces
{
    public interface ILocationService
    {
        Task<List<ProvinceDto>> GetProvincesAsync();
        Task<List<DistrictDto>> GetDistrictsByProvinceAsync(int provinceId);
        Task<List<WardDto>> GetWardsByDistrictAsync(int districtId);
    }
}
