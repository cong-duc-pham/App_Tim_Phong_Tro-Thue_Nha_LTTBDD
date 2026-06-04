using Backend_API.Models.DTOs.Payment;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers
{
    /// <summary>
    /// Xử lý callback thanh toán từ các cổng: MoMo, VNPay.
    /// Được gọi tự động bởi payment gateway sau khi user thanh toán.
    /// </summary>
    [ApiController]
    [Route("payment")]
    [Tags("Payment")]
    public class PaymentCallbackController : ControllerBase
    {
        private readonly IPaymentService _paymentService;

        public PaymentCallbackController(IPaymentService paymentService)
        {
            _paymentService = paymentService;
        }

        /// <summary>
        /// Callback từ MoMo sau khi thanh toán.
        /// </summary>
        /// <param name="transactionRef">Mã giao dịch tham chiếu</param>
        /// <response code="200">Xử lý callback thành công</response>
        /// <response code="400">Mã giao dịch không hợp lệ</response>
        [HttpGet("momo/callback")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> MomoCallback([FromQuery] string transactionRef)
        {
            try
            {
                await _paymentService.ProcessPaymentCallbackAsync(transactionRef, "momo");
                return Ok(new { success = true, message = "Đã xử lý callback MoMo thành công." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Callback từ VNPay sau khi thanh toán.
        /// </summary>
        /// <param name="transactionRef">Mã giao dịch tham chiếu</param>
        /// <response code="200">Xử lý callback thành công</response>
        /// <response code="400">Mã giao dịch không hợp lệ</response>
        [HttpGet("vnpay/callback")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> VNPayCallback([FromQuery] string transactionRef)
        {
            try
            {
                await _paymentService.ProcessPaymentCallbackAsync(transactionRef, "vnpay");
                return Ok(new { success = true, message = "Đã xử lý callback VNPay thành công." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [HttpPost("payos/webhook")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> PayOsWebhook([FromBody] PayOsWebhookDto webhook)
        {
            try
            {
                await _paymentService.ProcessPayOsWebhookAsync(webhook);
                return Ok(new { success = true });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [HttpGet("payos/return")]
        public IActionResult PayOsReturn()
        {
            return Ok(new { success = true, message = "PayOS return received. Please go back to the app." });
        }

        [HttpGet("payos/cancel")]
        public IActionResult PayOsCancel()
        {
            return Ok(new { success = false, message = "PayOS payment was cancelled." });
        }
    }
}
