using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Backend_API.Models.DTOs.Rentals;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers.API
{
    [ApiController]
    [Tags("Rentals")]
    public class RentalsApiController : ControllerBase
    {
        private readonly IRentalService _rentalService;

        public RentalsApiController(IRentalService rentalService)
        {
            _rentalService = rentalService;
        }

        /// <summary>
        /// Chủ nhà ghi nhận lịch sử thuê trọ cho một người thuê (bằng số điện thoại).
        /// </summary>
        [Authorize]
        [HttpPost("api/listings/{listingId:long}/rentals")]
        [ProducesResponseType(typeof(object), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> CreateRental(long listingId, [FromBody] RentalCreateDto dto)
        {
            try
            {
                long landlordId = GetCurrentUserId();
                var result = await _rentalService.CreateRentalAsync(landlordId, listingId, dto);
                return Created($"/api/listings/{listingId}/rentals", new { success = true, data = result });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách những người đang/đã thuê của chủ nhà hiện tại.
        /// </summary>
        [Authorize]
        [HttpGet("api/rentals/my-tenants")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMyTenants()
        {
            try
            {
                long landlordId = GetCurrentUserId();
                var items = await _rentalService.GetMyTenantsAsync(landlordId);
                return Ok(new { success = true, data = items, count = items.Count });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Lấy danh sách các phòng trọ mà người dùng hiện tại đang/đã thuê.
        /// </summary>
        [Authorize]
        [HttpGet("api/rentals/my-rented-rooms")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMyRentedRooms()
        {
            try
            {
                long tenantId = GetCurrentUserId();
                var items = await _rentalService.GetMyRentedRoomsAsync(tenantId);
                return Ok(new { success = true, data = items, count = items.Count });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Chủ nhà xác nhận người thuê đã thuê trọ trực tiếp từ phòng chat.
        /// </summary>
        [Authorize]
        [HttpPost("api/rentals/confirm-from-chat/{convId:long}")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> ConfirmRentalFromChat(long convId)
        {
            try
            {
                long landlordId = GetCurrentUserId();
                var result = await _rentalService.ConfirmRentalFromChatAsync(landlordId, convId);
                return Ok(new { success = true, data = result });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        private long GetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(claim) || !long.TryParse(claim, out long userId))
                throw new UnauthorizedAccessException();
            return userId;
        }
    }
}
