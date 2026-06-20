using System.Security.Claims;
using Backend_API.Models.DTOs.Appointments;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers.API
{
    [ApiController]
    [Route("api/viewing-appointments")]
    [Authorize]
    [Tags("Viewing Appointments")]
    public class ViewingAppointmentsApiController : ControllerBase
    {
        private readonly IViewingAppointmentService _appointmentService;

        public ViewingAppointmentsApiController(IViewingAppointmentService appointmentService)
        {
            _appointmentService = appointmentService;
        }

        [HttpGet]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMyAppointments([FromQuery] string? role, [FromQuery] string? status)
        {
            try
            {
                var userId = GetCurrentUserId();
                var items = await _appointmentService.GetMyAppointmentsAsync(userId, role, status);
                return Ok(new { success = true, data = items });
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

        [HttpPost]
        [ProducesResponseType(typeof(object), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> CreateAppointment([FromBody] CreateViewingAppointmentDto dto)
        {
            try
            {
                var userId = GetCurrentUserId();
                var created = await _appointmentService.CreateAsync(userId, dto);
                return Created($"/api/viewing-appointments/{created.AppointmentId}",
                    new { success = true, data = created });
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

        [AllowAnonymous]
        [HttpGet("listings/{listingId:long}/available-slots")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetAvailableSlots(
            long listingId,
            [FromQuery] DateOnly date,
            [FromQuery] int timezoneOffsetMinutes = 420)
        {
            try
            {
                var slots = await _appointmentService.GetAvailableSlotsAsync(
                    listingId,
                    date,
                    timezoneOffsetMinutes);
                return Ok(new { success = true, data = slots });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [HttpPatch("{id:long}/confirm")]
        public async Task<IActionResult> Confirm(long id, [FromBody] UpdateViewingAppointmentStatusDto dto)
        {
            return await UpdateStatus(() => _appointmentService.ConfirmAsync(id, GetCurrentUserId(), dto.Note));
        }

        [HttpPatch("{id:long}/decline")]
        public async Task<IActionResult> Decline(long id, [FromBody] UpdateViewingAppointmentStatusDto dto)
        {
            return await UpdateStatus(() => _appointmentService.DeclineAsync(id, GetCurrentUserId(), dto.Note));
        }

        [HttpPatch("{id:long}/cancel")]
        public async Task<IActionResult> Cancel(long id, [FromBody] UpdateViewingAppointmentStatusDto dto)
        {
            return await UpdateStatus(() => _appointmentService.CancelAsync(id, GetCurrentUserId(), dto.Note));
        }

        private async Task<IActionResult> UpdateStatus(Func<Task<ViewingAppointmentDto>> action)
        {
            try
            {
                var updated = await action();
                return Ok(new { success = true, data = updated });
            }
            catch (UnauthorizedAccessException ex)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new { success = false, message = ex.Message });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        private long GetCurrentUserId()
        {
            var claim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            if (string.IsNullOrEmpty(claim) || !long.TryParse(claim, out var userId))
            {
                throw new UnauthorizedAccessException();
            }

            return userId;
        }
    }
}
