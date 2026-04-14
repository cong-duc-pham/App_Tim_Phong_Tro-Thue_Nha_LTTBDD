using Backend_API.Models.DTOs.Payment;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Backend_API.Controllers.API
{
    /// <summary>
    /// Quản lý gói VIP và thanh toán: xem gói, mua gói, xem lịch sử hoá đơn.
    /// </summary>
    [ApiController]
    [Route("api/packages")]
    [Tags("Payment")]
    public class PackagesApiController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PackagesApiController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        /// <summary>
        /// Lấy danh sách các gói đăng tin (VIP packages).
        /// </summary>
        /// <returns>Danh sách gói với giá, thời hạn, mô tả</returns>
        /// <response code="200">Trả về danh sách gói</response>
        [HttpGet]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public async Task<IActionResult> GetPackages()
        {
            try
            {
                var packages = await _paymentService.GetPackagesAsync();
                return Ok(new { success = true, data = packages });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Mua gói VIP cho tin đăng → tạo hoá đơn chờ thanh toán.
        /// </summary>
        /// <param name="dto">ListingId và PackageId</param>
        /// <returns>Hoá đơn (Invoice) với thông tin thanh toán</returns>
        /// <response code="200">Tạo hoá đơn thành công</response>
        /// <response code="401">Chưa đăng nhập</response>
        /// <response code="400">Tin đăng hoặc gói không tồn tại</response>
        [Authorize]
        [HttpPost("purchase")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> PurchasePackage([FromBody] PurchasePackageDto dto)
        {
            try
            {
                long userId = GetCurrentUserId();
                var invoice = await _paymentService.CreateInvoiceAsync(userId, dto.ListingId, dto.PackageId);
                return Ok(new
                {
                    success = true,
                    message = "Tạo hóa đơn thành công. Vui lòng tiếp tục thanh toán.",
                    data = invoice
                });
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
        /// Lấy danh sách hoá đơn của tôi.
        /// </summary>
        /// <returns>Danh sách hoá đơn với trạng thái thanh toán</returns>
        /// <response code="200">Trả về danh sách hoá đơn</response>
        /// <response code="401">Chưa đăng nhập</response>
        [Authorize]
        [HttpGet("my-invoices")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> GetMyInvoices()
        {
            try
            {
                long userId = GetCurrentUserId();
                var invoices = await _paymentService.GetMyInvoicesAsync(userId);
                return Ok(new { success = true, data = invoices });
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
