using Backend_API.Models.DTOs.Auth;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Backend_API.Services;
using Backend_API.Helpers;
using FirebaseAdmin.Auth;
using Microsoft.EntityFrameworkCore;
using System.Threading.Tasks;
using System.Security.Cryptography;
using System.Text;

namespace Backend_API.Services.Implementations
{
    public class AuthService : IAuthService
    {
        private const string RefreshProvider = "internal_refresh";
        private const string PasswordResetOtpType = "forgot_password";
        private readonly PhongTroDbContext _context;
        private readonly JwtTokenHelper _jwtHelper;
        private readonly FirebaseHelper _firebaseHelper;
        private readonly IEmailService _emailService;

        public AuthService(
            PhongTroDbContext context,
            JwtTokenHelper jwtHelper,
            FirebaseHelper firebaseHelper,
            IEmailService emailService)
        {
            _context = context;
            _jwtHelper = jwtHelper;
            _firebaseHelper = firebaseHelper;
            _emailService = emailService;
        }

        public async Task<LoginResponseDto> RegisterAsync(RegisterRequestDto dto)
        {
            var email = NormalizeEmail(dto.Email);
            var isDuplicate = await _context.Users
                .AnyAsync(u => (u.Email != null && u.Email.ToLower() == email) || u.Phone == dto.Phone);
            if (isDuplicate)
            {
                throw new Exception("Email hoặc Số điện thoại đã được sử dụng.");
            }

            var hash = PasswordHasher.Hash(dto.Password);
            var newUser = new User
            {
                FullName = dto.FullName,
                Email = email,
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
            var email = NormalizeEmail(dto.Email);
            var user = await _context.Users
                .Include(u => u.Role)
                .Include(u => u.UserPreference)
                .FirstOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == email);
                
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
            var (uid, email, name, picture, provider) = await _firebaseHelper.VerifyIdToken(firebaseToken);
            
            // Theo như yêu cầu: gọi SP upsert
            // Đối số của SP thường theo thứ tự: uid, email, name, picture
            await _context.Database.ExecuteSqlInterpolatedAsync(
                $"EXEC sp_UpsertFirebaseUser {uid}, {email}, {name}, {picture}, {provider}, {uid}, {firebaseToken}");

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

        public async Task RequestPasswordResetOtpAsync(ForgotPasswordRequestDto dto)
        {
            var email = NormalizeEmail(dto.Email);
            var user = await FindOrCreatePasswordResetUserAsync(email);

            if (user == null)
            {
                throw new Exception("Email khong ton tai trong he thong.");
            }

            if (string.IsNullOrWhiteSpace(user.PasswordHash) && !IsFirebasePasswordUser(user))
            {
                throw new Exception("Tai khoan nay dang nhap bang Google/Facebook, khong can dat lai mat khau tai day.");
            }

            var oldOtps = await _context.OtpCodes
                .Where(o => o.UserId == user.UserId
                    && o.Contact == email
                    && o.OtpType == PasswordResetOtpType
                    && o.IsUsed != true)
                .ToListAsync();

            foreach (var oldOtp in oldOtps)
            {
                oldOtp.IsUsed = true;
            }

            var nowUtc = DateTime.UtcNow;
            var code = RandomNumberGenerator.GetInt32(100000, 1000000).ToString();
            var otp = new OtpCode
            {
                UserId = user.UserId,
                Contact = email,
                OtpType = PasswordResetOtpType,
                Code = code,
                IsUsed = false,
                CreatedAt = nowUtc,
                ExpiresAt = nowUtc.AddMinutes(10)
            };

            await _context.OtpCodes.AddAsync(otp);
            await _context.SaveChangesAsync();
            await _emailService.SendPasswordResetOtpAsync(email, code);
        }

        public async Task ResetPasswordWithOtpAsync(ResetPasswordWithOtpRequestDto dto)
        {
            var email = NormalizeEmail(dto.Email);
            var code = dto.OtpCode.Trim();
            var nowUtc = DateTime.UtcNow;

            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == email);

            if (user == null || (string.IsNullOrWhiteSpace(user.PasswordHash) && !IsFirebasePasswordUser(user)))
            {
                throw new Exception("Tai khoan khong hop le de dat lai mat khau.");
            }

            var otp = await _context.OtpCodes
                .Where(o => o.UserId == user.UserId
                    && o.Contact == email
                    && o.OtpType == PasswordResetOtpType
                    && o.Code == code
                    && o.IsUsed != true
                    && o.ExpiresAt > nowUtc)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (otp == null)
            {
                throw new Exception("OTP khong dung hoac da het han.");
            }

            otp.IsUsed = true;
            user.PasswordHash = PasswordHasher.Hash(dto.NewPassword);
            user.UpdatedAt = nowUtc;
            await _context.SaveChangesAsync();
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

        private static string NormalizeEmail(string email)
        {
            return email.Trim().ToLowerInvariant();
        }

        private static bool IsFirebasePasswordUser(User user)
        {
            return string.Equals(user.FirebaseProvider, "password", StringComparison.OrdinalIgnoreCase);
        }

        private async Task<User?> FindOrCreatePasswordResetUserAsync(string email)
        {
            var user = await _context.Users
                .FirstOrDefaultAsync(u => u.Email != null && u.Email.ToLower() == email);

            if (user != null)
            {
                return user;
            }

            UserRecord firebaseUser;
            try
            {
                firebaseUser = await FirebaseAuth.DefaultInstance.GetUserByEmailAsync(email);
            }
            catch
            {
                return null;
            }

            var hasPasswordProvider = firebaseUser.ProviderData.Any(p =>
                string.Equals(p.ProviderId, "password", StringComparison.OrdinalIgnoreCase));

            if (!hasPasswordProvider)
            {
                return new User
                {
                    FullName = firebaseUser.DisplayName ?? email,
                    Email = email,
                    FirebaseUid = firebaseUser.Uid,
                    FirebaseProvider = firebaseUser.ProviderData.FirstOrDefault()?.ProviderId
                };
            }

            var nowUtc = DateTime.UtcNow;
            user = new User
            {
                FullName = string.IsNullOrWhiteSpace(firebaseUser.DisplayName)
                    ? email.Split('@')[0]
                    : firebaseUser.DisplayName,
                Email = email,
                Phone = firebaseUser.PhoneNumber,
                FirebaseUid = firebaseUser.Uid,
                FirebaseProvider = "password",
                RoleId = 2,
                IsActive = true,
                IsVerified = firebaseUser.EmailVerified,
                CreatedAt = nowUtc,
                UpdatedAt = nowUtc
            };

            await _context.Users.AddAsync(user);
            await _context.SaveChangesAsync();

            await _context.UserPreferences.AddAsync(new UserPreference
            {
                UserId = user.UserId,
                OnboardingDone = false
            });
            await _context.SaveChangesAsync();

            return user;
        }

        public async Task ChangePasswordAsync(long userId, ChangePasswordRequestDto dto)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("Không tìm thấy người dùng.");
            }

            if (!string.IsNullOrEmpty(user.PasswordHash))
            {
                if (!PasswordHasher.Verify(dto.CurrentPassword, user.PasswordHash))
                {
                    throw new Exception("Mật khẩu hiện tại không chính xác.");
                }
            }

            user.PasswordHash = PasswordHasher.Hash(dto.NewPassword);
            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        public async Task UpdateProfileAsync(long userId, UpdateProfileRequestDto dto)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("Không tìm thấy người dùng.");
            }

            user.FullName = dto.FullName.Trim();
            user.Phone = dto.Phone?.Trim();
            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }
    }
}
