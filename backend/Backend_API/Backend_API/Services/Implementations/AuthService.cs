using Backend_API.Models.DTOs.Auth;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Backend_API.Helpers;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System.Security.Cryptography;
using System.Text;

namespace Backend_API.Services.Implementations
{
    public class AuthService : IAuthService
    {
        private const string RefreshProvider = "internal_refresh";
        private readonly PhongTroDbContext _context;
        private readonly JwtTokenHelper _jwtHelper;
        private readonly FirebaseHelper _firebaseHelper;

        public AuthService(PhongTroDbContext context, JwtTokenHelper jwtHelper, FirebaseHelper firebaseHelper)
        {
            _context = context;
            _jwtHelper = jwtHelper;
            _firebaseHelper = firebaseHelper;
        }

        public async Task<LoginResponseDto> RegisterAsync(RegisterRequestDto dto)
        {
            var isDuplicate = await _context.Users
                .AnyAsync(u => u.Email == dto.Email || u.Phone == dto.Phone);
            if (isDuplicate)
            {
                throw new Exception("Email hoặc Số điện thoại đã được sử dụng.");
            }

            var hash = PasswordHasher.Hash(dto.Password);
            var newUser = new User
            {
                FullName = dto.FullName,
                Email = dto.Email,
                Phone = dto.Phone,
                PasswordHash = hash,
                RoleId = 2, // Default: Tenant
                IsActive = true
            };

            await _context.Users.AddAsync(newUser);
            await _context.SaveChangesAsync();

            var preference = new UserPreference
            {
                UserId = newUser.UserId,
                OnboardingDone = false
            };
            await _context.UserPreferences.AddAsync(preference);
            await _context.SaveChangesAsync();

            // Lấy lại user bao gồm Role để GenerateToken đầy đủ
            var userWithRole = await _context.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.UserId == newUser.UserId);

            var token = _jwtHelper.GenerateToken(userWithRole ?? newUser);
            var refreshToken = await IssueRefreshTokenAsync(newUser.UserId);

            return new LoginResponseDto
            {
                AccessToken = token,
                RefreshToken = refreshToken,
                UserId = newUser.UserId,
                FullName = newUser.FullName,
                Role = userWithRole?.Role?.RoleName ?? "Tenant",
                IsNewUser = true
            };
        }

        public async Task<LoginResponseDto> LoginAsync(LoginRequestDto dto)
        {
            var user = await _context.Users
                .Include(u => u.Role)
                .FirstOrDefaultAsync(u => u.Email == dto.Email);
                
            if (user == null || string.IsNullOrEmpty(user.PasswordHash) || !PasswordHasher.Verify(dto.Password, user.PasswordHash))
            {
                throw new Exception("Thông tin đăng nhập không hợp lệ.");
            }

            user.LastLogin = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            var token = _jwtHelper.GenerateToken(user);
            var refreshToken = await IssueRefreshTokenAsync(user.UserId);
            
            return new LoginResponseDto
            {
                AccessToken = token,
                RefreshToken = refreshToken,
                UserId = user.UserId,
                FullName = user.FullName,
                Role = user.Role?.RoleName ?? "Tenant",
                IsNewUser = false
            };
        }

        public async Task<LoginResponseDto> LoginWithFirebaseAsync(string firebaseToken)
        {
            // 1. Xác thực Firebase Token
            var (uid, email, name, picture) = await _firebaseHelper.VerifyIdToken(firebaseToken);
            
            // Theo như yêu cầu: gọi SP upsert
            // Đối số của SP thường theo thứ tự: uid, email, name, picture
            await _context.Database.ExecuteSqlInterpolatedAsync($"EXEC sp_UpsertFirebaseUser {uid}, {email}, {name}, {picture}");

            // Load lại User vừa Upsert xong
            var user = await _context.Users
                .Include(u => u.Role)
                .Include(u => u.UserPreference)
                .FirstOrDefaultAsync(u => u.FirebaseUid == uid);

            if (user == null)
            {
                throw new Exception("Không thể đồng bộ người dùng từ Firebase.");
            }

            user.LastLogin = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            var token = _jwtHelper.GenerateToken(user);
            var refreshToken = await IssueRefreshTokenAsync(user.UserId);
            
            // Nếu là user mới thì preference thường OnboardingDone = false
            bool isNewUser = user.UserPreference == null || user.UserPreference.OnboardingDone != true;

            return new LoginResponseDto
            {
                AccessToken = token,
                RefreshToken = refreshToken,
                UserId = user.UserId,
                FullName = user.FullName,
                Role = user.Role?.RoleName ?? "Tenant",
                IsNewUser = isNewUser
            };
        }

        public async Task UpdateFcmTokenAsync(long userId, string token)
        {
            await _context.Database.ExecuteSqlInterpolatedAsync($"EXEC sp_UpdateFcmToken {userId}, {token}, 'android'");
        }

        public async Task<LoginResponseDto> RefreshTokenAsync(string refreshToken)
        {
            if (string.IsNullOrWhiteSpace(refreshToken))
            {
                throw new Exception("Refresh token không hợp lệ.");
            }

            var normalized = refreshToken.Trim();
            var hashed = HashRefreshToken(normalized);
            var nowUtc = DateTime.UtcNow;

            var provider = await _context.SocialAuthProviders
                .FirstOrDefaultAsync(p =>
                    p.Provider == RefreshProvider &&
                    p.RefreshToken == hashed &&
                    p.TokenExpiresAt != null &&
                    p.TokenExpiresAt > nowUtc);

            if (provider == null)
            {
                throw new Exception("Refresh token đã hết hạn hoặc không tồn tại.");
            }

            var user = await _context.Users
                .Include(u => u.Role)
                .Include(u => u.UserPreference)
                .FirstOrDefaultAsync(u => u.UserId == provider.UserId && u.IsActive == true);

            if (user == null)
            {
                throw new Exception("Không tìm thấy người dùng hợp lệ cho refresh token.");
            }

            var newAccessToken = _jwtHelper.GenerateToken(user);
            var newRefreshToken = GenerateSecureToken(64);

            provider.RefreshToken = HashRefreshToken(newRefreshToken);
            provider.TokenExpiresAt = nowUtc.AddDays(14);
            provider.UpdatedAt = nowUtc;
            provider.AccessToken = null;
            await _context.SaveChangesAsync();

            return new LoginResponseDto
            {
                AccessToken = newAccessToken,
                RefreshToken = newRefreshToken,
                UserId = user.UserId,
                FullName = user.FullName,
                Role = user.Role?.RoleName ?? "Tenant",
                IsNewUser = user.UserPreference == null || user.UserPreference.OnboardingDone != true
            };
        }

        private async Task<string> IssueRefreshTokenAsync(long userId)
        {
            var rawToken = GenerateSecureToken(64);
            var nowUtc = DateTime.UtcNow;
            var tokenHash = HashRefreshToken(rawToken);

            var provider = await _context.SocialAuthProviders
                .FirstOrDefaultAsync(p => p.UserId == userId && p.Provider == RefreshProvider);

            if (provider == null)
            {
                provider = new SocialAuthProvider
                {
                    UserId = userId,
                    Provider = RefreshProvider,
                    ProviderUid = $"user:{userId}",
                    RefreshToken = tokenHash,
                    TokenExpiresAt = nowUtc.AddDays(14),
                    CreatedAt = nowUtc,
                    UpdatedAt = nowUtc
                };
                await _context.SocialAuthProviders.AddAsync(provider);
            }
            else
            {
                provider.RefreshToken = tokenHash;
                provider.TokenExpiresAt = nowUtc.AddDays(14);
                provider.UpdatedAt = nowUtc;
            }

            await _context.SaveChangesAsync();
            return rawToken;
        }

        private static string GenerateSecureToken(int bytesLength)
        {
            var bytes = RandomNumberGenerator.GetBytes(bytesLength);
            return Convert.ToBase64String(bytes)
                .Replace("+", "-")
                .Replace("/", "_")
                .TrimEnd('=');
        }

        private static string HashRefreshToken(string token)
        {
            var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
            return Convert.ToHexString(bytes);
        }
    }
}
