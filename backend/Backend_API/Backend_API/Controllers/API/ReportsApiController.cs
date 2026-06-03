using Backend_API.Models.DTOs.Reports;
using Backend_API.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    [ApiController]
    [Route("api/reports")]
    [Authorize]
    [Tags("Reports")]
    public class ReportsApiController : ControllerBase
    {
        private const string ReportStatusPending = "pending";
        private readonly PhongTroDbContext _context;

        public ReportsApiController(PhongTroDbContext context)
        {
            _context = context;
        }

        [HttpPost]
        [ProducesResponseType(typeof(object), StatusCodes.Status201Created)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> CreateReport([FromBody] ReportCreateDto dto)
        {
            try
            {
                var reason = dto.Reason.Trim();
                if (string.IsNullOrWhiteSpace(reason))
                {
                    return BadRequest(new { success = false, message = "Vui lòng chọn lý do báo cáo." });
                }

                var report = new Report
                {
                    ReporterId = GetCurrentUserId(),
                    ListingId = dto.ListingId,
                    UserId = dto.UserId,
                    Reason = reason,
                    Description = string.IsNullOrWhiteSpace(dto.Description)
                        ? null
                        : dto.Description.Trim(),
                    Status = ReportStatusPending,
                    CreatedAt = DateTime.UtcNow
                };

                _context.Reports.Add(report);
                await _context.SaveChangesAsync();

                return Created($"/api/reports/{report.ReportId}", new
                {
                    success = true,
                    message = "Đã ghi nhận báo cáo.",
                    data = new { report.ReportId }
                });
            }
            catch (UnauthorizedAccessException)
            {
                return Unauthorized(new { success = false, message = "Chưa đăng nhập." });
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
