using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Dữ liệu địa lý: Tỉnh/Thành phố, Quận/Huyện, Phường/Xã.
    /// </summary>
    [ApiController]
    [Route("api/locations")]
    [Tags("Locations")]
    public class LocationsApiController : ControllerBase
    {
        private readonly ILocationService _locationService;

        public LocationsApiController(ILocationService locationService)
        {
            _locationService = locationService;
        }

        /// <summary>
        /// Lấy danh sách tất cả Tỉnh/Thành phố.
        /// </summary>
        /// <returns>Danh sách provinces</returns>
        /// <response code="200">Trả về danh sách tỉnh/thành phố</response>
        [HttpGet("provinces")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetProvinces()
        {
            try
            {
                var data = await _locationService.GetProvincesAsync();
                return Ok(new { success = true, data });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách Quận/Huyện theo Tỉnh.
        /// </summary>
        /// <param name="provinceId">ID tỉnh/thành phố</param>
        /// <returns>Danh sách quận/huyện</returns>
        /// <response code="200">Trả về danh sách quận/huyện</response>
        [HttpGet("districts/{provinceId:int}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetDistricts(int provinceId)
        {
            try
            {
                var data = await _locationService.GetDistrictsByProvinceAsync(provinceId);
                return Ok(new { success = true, data });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách Phường/Xã theo Quận/Huyện.
        /// </summary>
        /// <param name="districtId">ID quận/huyện</param>
        /// <returns>Danh sách phường/xã</returns>
        /// <response code="200">Trả về danh sách phường/xã</response>
        [HttpGet("wards/{districtId:int}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetWards(int districtId)
        {
            try
            {
                var data = await _locationService.GetWardsByDistrictAsync(districtId);
                return Ok(new { success = true, data });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }
    }
}
