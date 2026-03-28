using Backend_API.Models.DTOs;
using Backend_API.Services;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers;

[ApiController]
[Route("api/auth")]
public class AuthController : ControllerBase
{
    private readonly IAuthService _auth;

    public AuthController(IAuthService auth) => _auth = auth;

    /// <summary>Đăng ký tài khoản mới</summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest req)
    {
        var result = await _auth.RegisterAsync(req);
        if (result == null)
            return Conflict(new ApiResponse<object>(false, "Email đã được sử dụng", null));

        return Ok(new ApiResponse<AuthResponse>(true, "Đăng ký thành công", result));
    }

    /// <summary>Đăng nhập</summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest req)
    {
        var result = await _auth.LoginAsync(req);
        if (result == null)
            return Unauthorized(new ApiResponse<object>(false, "Email hoặc mật khẩu không đúng", null));

        return Ok(new ApiResponse<AuthResponse>(true, "Đăng nhập thành công", result));
    }

    /// <summary>Gửi OTP qua email</summary>
    [HttpPost("send-otp")]
    public async Task<IActionResult> SendOtp([FromBody] SendOtpRequest req)
    {
        await _auth.SendOtpAsync(req.Email, req.Purpose);
        return Ok(new ApiResponse<object>(true, "OTP đã được gửi đến email của bạn", null));
    }

    /// <summary>Xác minh OTP</summary>
    [HttpPost("verify-otp")]
    public async Task<IActionResult> VerifyOtp([FromBody] VerifyOtpRequest req)
    {
        var success = await _auth.VerifyOtpAsync(req.Email, req.Code, req.Purpose);
        if (!success)
            return BadRequest(new ApiResponse<object>(false, "OTP không hợp lệ hoặc đã hết hạn", null));

        return Ok(new ApiResponse<object>(true, "Xác minh thành công", null));
    }
}
