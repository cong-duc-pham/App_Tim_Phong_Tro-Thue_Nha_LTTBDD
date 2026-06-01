using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using Backend_API.Models.DTOs.Auth;
using Backend_API.Services.Interfaces;
using System.Security.Claims;
using System.Threading.Tasks;
using System;

namespace Backend_API.Controllers
{
    public class UpdateFcmRequestDto
    {
        public string FcmToken { get; set; } = null!;
    }

    /// <summary>
    /// Xác thực người dùng: Đăng ký, Đăng nhập, Firebase Login, FCM Token.
    /// </summary>
    [ApiController]
    [Route("api/auth")]
    [Tags("Auth")]
    public class AuthApiController : ControllerBase
    {
        private readonly IAuthService _authService;

        public AuthApiController(IAuthService authService)
        {
            _authService = authService;
        }

        /// <summary>
        /// Đăng ký tài khoản mới bằng email/password.
        /// </summary>
        /// <param name="request">Thông tin đăng ký: Email, Password, FullName, Phone</param>
        /// <returns>JWT Token và thông tin user</returns>
        /// <response code="200">Đăng ký thành công, trả về JWT token</response>
        /// <response code="400">Email đã tồn tại hoặc dữ liệu không hợp lệ</response>
        [HttpPost("register")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Register([FromBody] RegisterRequestDto request)
        {
            try
            {
                var result = await _authService.RegisterAsync(request);
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Đăng nhập bằng email/password → nhận JWT Token.
        /// </summary>
        /// <param name="request">Email và Password</param>
        /// <returns>JWT Token và thông tin user</returns>
        /// <response code="200">Đăng nhập thành công</response>
        /// <response code="400">Sai email hoặc mật khẩu</response>
        [HttpPost("login")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> Login([FromBody] LoginRequestDto request)
        {
            try
            {
                var result = await _authService.LoginAsync(request);
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [HttpPost("forgot-password")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> ForgotPassword([FromBody] ForgotPasswordRequestDto request)
        {
            try
            {
                await _authService.RequestPasswordResetOtpAsync(request);
                return Ok(new { success = true, message = "Da gui OTP dat lai mat khau. Vui long kiem tra email." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        [HttpPost("reset-password")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> ResetPassword([FromBody] ResetPasswordWithOtpRequestDto request)
        {
            try
            {
                await _authService.ResetPasswordWithOtpAsync(request);
                return Ok(new { success = true, message = "Dat lai mat khau thanh cong." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Đăng nhập bằng Firebase Token (Google Sign-In).
        /// Firebase Token được verify qua Admin SDK → tạo/lấy user → trả JWT.
        /// </summary>
        /// <param name="request">Firebase ID Token (và tùy chọn DeviceToken cho FCM)</param>
        /// <returns>JWT Token và thông tin user</returns>
        /// <response code="200">Xác thực Firebase thành công</response>
        /// <response code="400">Firebase Token không hợp lệ</response>
        [HttpPost("firebase-login")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> FirebaseLogin([FromBody] FirebaseLoginRequestDto request)
        {
            try
            {
                var result = await _authService.LoginWithFirebaseAsync(request.FirebaseToken);
                
                // Nếu User có gửi kèm DeviceToken lúc Firebase Login, cập nhật luôn
                if (!string.IsNullOrEmpty(request.DeviceToken))
                {
                    await _authService.UpdateFcmTokenAsync(result.UserId, request.DeviceToken);
                }

                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Cập nhật FCM Device Token cho push notification.
        /// Gọi sau khi đăng nhập thành công hoặc khi token thay đổi.
        /// </summary>
        /// <param name="request">FCM Token mới từ Firebase Messaging</param>
        /// <response code="200">Cập nhật FCM Token thành công</response>
        /// <response code="401">Chưa đăng nhập (thiếu JWT)</response>
        [Authorize]
        [HttpPost("update-fcm-token")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        public async Task<IActionResult> UpdateFcmToken([FromBody] UpdateFcmRequestDto request)
        {
            try
            {
                var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userIdStr) || !long.TryParse(userIdStr, out long userId))
                {
                    return Unauthorized(new { success = false, message = "Không xác định được danh tính người dùng." });
                }

                await _authService.UpdateFcmTokenAsync(userId, request.FcmToken);
                return Ok(new { success = true, message = "Cập nhật FCM Token thành công." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Đăng xuất (Stateless JWT — client tự xoá token).
        /// </summary>
        /// <response code="200">Đăng xuất thành công</response>
        [HttpPost("logout")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        public IActionResult Logout()
        {
            // Trong kiểu hình Stateless JWT, việc xoá Token là nhiệm vụ của Frontend.
            // Có thể mở rộng để vô hiệu hóa Token bằng Redis/Database nếu cần bảo mật nghiêm ngặt.
            return Ok(new { success = true, message = "Đăng xuất thành công. Vui lòng xoá token ở Frontend." });
        }

        /// <summary>
        /// Làm mới Access Token bằng Refresh Token.
        /// </summary>
        [HttpPost("refresh-token")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequestDto request)
        {
            try
            {
                var result = await _authService.RefreshTokenAsync(request.RefreshToken);
                return Ok(new { success = true, data = result });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }

        /// <summary>
        /// Đổi mật khẩu cho người dùng hiện tại.
        /// </summary>
        [Authorize]
        [HttpPost("change-password")]
        [ProducesResponseType(typeof(object), StatusCodes.Status200OK)]
        [ProducesResponseType(typeof(object), StatusCodes.Status401Unauthorized)]
        [ProducesResponseType(typeof(object), StatusCodes.Status400BadRequest)]
        public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordRequestDto request)
        {
            try
            {
                var userIdStr = User.FindFirstValue(ClaimTypes.NameIdentifier);
                if (string.IsNullOrEmpty(userIdStr) || !long.TryParse(userIdStr, out long userId))
                {
                    return Unauthorized(new { success = false, message = "Không xác định được danh tính người dùng." });
                }

                await _authService.ChangePasswordAsync(userId, request);
                return Ok(new { success = true, message = "Đổi mật khẩu thành công." });
            }
            catch (Exception ex)
            {
                return BadRequest(new { success = false, message = ex.Message });
            }
        }
    }
}
