using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Backend_API.Models.DTOs.Auth;
using Backend_API.Services.Interfaces;

namespace Backend_API.Controllers.MVC
{
    [Route("auth")]
    public class AuthController : Controller
    {
        private readonly IAuthService _authService;

        public AuthController(IAuthService authService)
        {
            _authService = authService;
        }

        [HttpGet("login")]
        public IActionResult Login(string? returnUrl = null)
        {
            ViewData["ReturnUrl"] = returnUrl;
            return View();
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromForm] LoginRequestDto request, string? returnUrl = null)
        {
            try
            {
                var result = await _authService.LoginAsync(request);

                // Tạo Cookie theo chuẩn ASP.NET
                var claims = new List<Claim>
                {
                    new Claim(ClaimTypes.NameIdentifier, result.UserId.ToString()),
                    new Claim(ClaimTypes.Name, result.FullName),
                    new Claim(ClaimTypes.Email, request.Email),
                    new Claim(ClaimTypes.Role, result.Role)
                };

                var claimsIdentity = new ClaimsIdentity(claims, CookieAuthenticationDefaults.AuthenticationScheme);

                await HttpContext.SignInAsync(
                    CookieAuthenticationDefaults.AuthenticationScheme,
                    new ClaimsPrincipal(claimsIdentity));

                if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
                {
                    return Redirect(returnUrl);
                }

                return RedirectToAction("Dashboard", "Admin");
            }
            catch (Exception ex)
            {
                ViewBag.Error = ex.Message;
                return View(request);
            }
        }

        [HttpGet("register")]
        public IActionResult Register()
        {
            return View();
        }
        
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromForm] RegisterRequestDto request)
        {
            try
            {
                await _authService.RegisterAsync(request);
                return RedirectToAction("Login", new { message = "Đăng ký thành công. Vui lòng đăng nhập!" });
            }
            catch (Exception ex)
            {
                ViewBag.Error = ex.Message;
                return View(request);
            }
        }

        [HttpPost("logout")]
        [HttpGet("logout")]
        public async Task<IActionResult> Logout()
        {
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction("Login", "Auth");
        }
    }
}
