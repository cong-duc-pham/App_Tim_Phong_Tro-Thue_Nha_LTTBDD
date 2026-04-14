using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Master Data API: endpoint gộp cho Tỉnh/Huyện/Xã, Loại phòng, Tiện ích.
    /// Dùng khi Flutter cần load tất cả dữ liệu tham chiếu cùng lúc.
    /// </summary>
    [ApiController]
    [Route("api/master-data")]
    [Tags("Master Data")]
    public class MasterDataApiController : ControllerBase
    {
        private readonly ILocationService _locationService;
        private readonly ICategoryService _categoryService;

        public MasterDataApiController(ILocationService locationService, ICategoryService categoryService)
        {
            _locationService = locationService;
            _categoryService = categoryService;
        }

        /// <summary>
        /// Lấy danh sách Tỉnh/Thành phố.
        /// </summary>
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
        /// Lấy danh sách Quận/Huyện theo tỉnh.
        /// </summary>
        /// <param name="provinceId">ID tỉnh/thành phố</param>
        /// <response code="200">Trả về danh sách quận/huyện</response>
        [HttpGet("districts/{provinceId}")]
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
        /// Lấy danh sách Phường/Xã theo quận/huyện.
        /// </summary>
        /// <param name="districtId">ID quận/huyện</param>
        /// <response code="200">Trả về danh sách phường/xã</response>
        [HttpGet("wards/{districtId}")]
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

        /// <summary>
        /// Lấy danh sách Loại phòng.
        /// </summary>
        /// <response code="200">Trả về danh sách loại phòng</response>
        [HttpGet("room-types")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetRoomTypes()
        {
            try
            {
                var data = await _categoryService.GetRoomTypesAsync();
                return Ok(new { success = true, data });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách Tiện ích.
        /// </summary>
        /// <response code="200">Trả về danh sách tiện ích</response>
        [HttpGet("amenities")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAmenities()
        {
            try
            {
                var data = await _categoryService.GetAmenitiesAsync();
                return Ok(new { success = true, data });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }
    }
}
