using System.Security.Claims;
using Backend_API.Data;
using Backend_API.Models.DTOs;
using Backend_API.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers;

[ApiController]
[Route("api/users")]
[Authorize]
public class UsersController : ControllerBase
{
    private readonly AppDbContext _db;

    public UsersController(AppDbContext db) => _db = db;

    /// <summary>Lấy thông tin profile của tôi</summary>
    [HttpGet("me")]
    public async Task<IActionResult> GetProfile()
    {
        var userId = GetUserId();
        var user = await _db.Users
            .Include(u => u.Role)
            .FirstOrDefaultAsync(u => u.UserId == userId);

        if (user == null) return NotFound();

        var dto = new UserProfileDto(
            user.UserId, user.FullName, user.Email, user.Phone, user.AvatarUrl,
            user.Gender.HasValue ? (user.Gender == 0 ? "Nam" : user.Gender == 1 ? "Nữ" : "Khác") : null,
            user.DateOfBirth, user.Role.RoleName, user.IsVerified, user.CreatedAt
        );
        return Ok(new ApiResponse<UserProfileDto>(true, null, dto));
    }

    /// <summary>Cập nhật profile</summary>
    [HttpPut("me")]
    public async Task<IActionResult> UpdateProfile([FromBody] UpdateProfileRequest req)
    {
        var userId = GetUserId();
        var user = await _db.Users.FindAsync(userId);
        if (user == null) return NotFound();

        if (req.FullName != null) user.FullName = req.FullName;
        if (req.Phone != null) user.Phone = req.Phone;
        if (req.AvatarUrl != null) user.AvatarUrl = req.AvatarUrl;
        if (req.Gender.HasValue) user.Gender = req.Gender;
        if (req.DateOfBirth.HasValue) user.DateOfBirth = req.DateOfBirth;
        user.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(true, "Cập nhật thành công", null));
    }

    /// <summary>Lấy preferences (nhu cầu tìm phòng)</summary>
    [HttpGet("me/preferences")]
    public async Task<IActionResult> GetPreferences()
    {
        var userId = GetUserId();
        var pref = await _db.UserPreferences.FirstOrDefaultAsync(p => p.UserId == userId);
        return Ok(new ApiResponse<object>(true, null, pref));
    }

    /// <summary>Lưu preferences sau onboarding</summary>
    [HttpPost("me/preferences")]
    public async Task<IActionResult> SavePreferences([FromBody] SavePreferencesRequest req)
    {
        var userId = GetUserId();
        var pref = await _db.UserPreferences.FirstOrDefaultAsync(p => p.UserId == userId);

        if (pref == null)
        {
            pref = new UserPreference { UserId = userId!.Value, CreatedAt = DateTime.UtcNow };
            _db.UserPreferences.Add(pref);
        }

        pref.PreferredArea = req.PreferredArea;
        pref.MinPrice = req.MinPrice;
        pref.MaxPrice = req.MaxPrice;
        pref.AllowPet = req.AllowPet;
        pref.Latitude = req.Latitude;
        pref.Longitude = req.Longitude;
        pref.SearchRadiusKm = req.SearchRadiusKm;
        pref.OnboardingDone = true;
        pref.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(true, "Đã lưu nhu cầu tìm phòng", null));
    }

    private long? GetUserId()
    {
        var claim = User.FindFirst("userId")?.Value;
        return long.TryParse(claim, out var id) ? id : null;
    }
}
