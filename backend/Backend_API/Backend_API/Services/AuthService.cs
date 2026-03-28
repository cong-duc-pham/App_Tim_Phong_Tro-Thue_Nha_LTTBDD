using Backend_API.Data;
using Backend_API.Models.DTOs;
using Backend_API.Models.Entities;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services;

public interface IAuthService
{
    Task<AuthResponse?> RegisterAsync(RegisterRequest req);
    Task<AuthResponse?> LoginAsync(LoginRequest req);
    Task<bool> SendOtpAsync(string email, string purpose);
    Task<bool> VerifyOtpAsync(string email, string code, string purpose);
}

public class AuthService : IAuthService
{
    private readonly AppDbContext _db;
    private readonly IJwtService _jwt;
    private readonly IEmailService _email;

    public AuthService(AppDbContext db, IJwtService jwt, IEmailService email)
    {
        _db = db;
        _jwt = jwt;
        _email = email;
    }

    public async Task<AuthResponse?> RegisterAsync(RegisterRequest req)
    {
        // Kiểm tra email đã tồn tại chưa
        if (await _db.Users.AnyAsync(u => u.Email == req.Email))
            return null;

        var role = await _db.Roles.FirstOrDefaultAsync(r => r.RoleName == req.Role)
                   ?? await _db.Roles.FirstAsync(r => r.RoleName == "tenant");

        var user = new User
        {
            FullName = req.FullName,
            Email = req.Email,
            Phone = req.Phone,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
            RoleId = role.RoleId,
            IsVerified = false,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();
        user.Role = role;

        var token = _jwt.GenerateToken(user);

        return new AuthResponse(
            user.UserId, user.FullName, user.Email!, user.Phone,
            user.AvatarUrl, role.RoleName, token, false
        );
    }

    public async Task<AuthResponse?> LoginAsync(LoginRequest req)
    {
        var user = await _db.Users
            .Include(u => u.Role)
            .Include(u => u.Preference)
            .FirstOrDefaultAsync(u => u.Email == req.Email && u.IsActive);

        if (user == null || user.PasswordHash == null)
            return null;

        if (!BCrypt.Net.BCrypt.Verify(req.Password, user.PasswordHash))
            return null;

        // Cập nhật last_login
        user.LastLogin = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        var token = _jwt.GenerateToken(user);
        var onboardingDone = user.Preference?.OnboardingDone ?? false;

        return new AuthResponse(
            user.UserId, user.FullName, user.Email!, user.Phone,
            user.AvatarUrl, user.Role.RoleName, token, onboardingDone
        );
    }

    public async Task<bool> SendOtpAsync(string email, string purpose)
    {
        var otp = new Random().Next(100000, 999999).ToString();

        // Hủy các OTP cũ chưa dùng
        var oldOtps = await _db.OtpCodes
            .Where(o => o.Contact == email && o.OtpType == purpose && !o.IsUsed)
            .ToListAsync();
        _db.OtpCodes.RemoveRange(oldOtps);

        _db.OtpCodes.Add(new OtpCode
        {
            Contact = email,
            OtpType = purpose,
            Code = otp,
            ExpiresAt = DateTime.UtcNow.AddMinutes(5),
            CreatedAt = DateTime.UtcNow
        });
        await _db.SaveChangesAsync();

        await _email.SendOtpAsync(email, otp, purpose);
        return true;
    }

    public async Task<bool> VerifyOtpAsync(string email, string code, string purpose)
    {
        var otpRecord = await _db.OtpCodes
            .Where(o => o.Contact == email
                     && o.Code == code
                     && o.OtpType == purpose
                     && !o.IsUsed
                     && o.ExpiresAt > DateTime.UtcNow)
            .FirstOrDefaultAsync();

        if (otpRecord == null) return false;

        otpRecord.IsUsed = true;

        // Nếu là verify tài khoản → đánh dấu IsVerified
        if (purpose == "register" || purpose == "verify")
        {
            var user = await _db.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user != null) user.IsVerified = true;
        }

        await _db.SaveChangesAsync();
        return true;
    }
}
