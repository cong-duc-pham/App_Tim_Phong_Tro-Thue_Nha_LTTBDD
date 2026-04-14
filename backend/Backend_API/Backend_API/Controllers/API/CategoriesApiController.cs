using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Dữ liệu danh mục: Loại phòng (RoomType), Tiện ích (Amenity).
    /// </summary>
    [ApiController]
    [Route("api/categories")]
    [Tags("Categories")]
    public class CategoriesApiController : ControllerBase
    {
        private readonly ICategoryService _categoryService;

        public CategoriesApiController(ICategoryService categoryService)
        {
            _categoryService = categoryService;
        }

        /// <summary>
        /// Lấy danh sách tất cả Loại phòng (RoomType).
        /// </summary>
        /// <returns>Danh sách room types</returns>
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
        /// Lấy danh sách tất cả Tiện ích (Amenity).
        /// </summary>
        /// <returns>Danh sách amenities</returns>
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
