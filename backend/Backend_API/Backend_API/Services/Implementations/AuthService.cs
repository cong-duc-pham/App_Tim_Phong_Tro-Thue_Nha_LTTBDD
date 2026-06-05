using Backend_API.Models.DTOs.Auth;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Backend_API.Services;
using Backend_API.Helpers;
using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Hosting;
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
        private const string PhoneVerificationOtpType = "phone_verification";
        private const string EmailVerificationOtpType = "email_verification";
        private readonly PhongTroDbContext _context;
        private readonly JwtTokenHelper _jwtHelper;
        private readonly FirebaseHelper _firebaseHelper;
        private readonly IEmailService _emailService;
        private readonly ISmsService _smsService;
        private readonly IWebHostEnvironment _environment;
        private readonly IConfiguration _configuration;

        public AuthService(
            PhongTroDbContext context,
            JwtTokenHelper jwtHelper,
            FirebaseHelper firebaseHelper,
            IEmailService emailService,
            ISmsService smsService,
            IWebHostEnvironment environment,
            IConfiguration configuration)
        {
            _context = context;
            _jwtHelper = jwtHelper;
            _firebaseHelper = firebaseHelper;
            _emailService = emailService;
            _smsService = smsService;
            _environment = environment;
            _configuration = configuration;
        }

        public async Task<LoginResponseDto> RegisterAsync(RegisterRequestDto dto)
        {
            var email = NormalizeEmail(dto.Email);
            var isDuplicate = await _context.Users
                .AnyAsync(u => (u.Email != null && u.Email.ToLower() == email) || u.Phone == dto.Phone);
            if (isDuplicate)
            {
                throw new Exception("Email hoáº·c Sá»‘ Ä‘iá»‡n thoáº¡i Ä‘Ã£ Ä‘Æ°á»£c sá»­ dá»¥ng.");
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

            // Láº¥y láº¡i user bao gá»“m Role Ä‘á»ƒ GenerateToken Ä‘áº§y Ä‘á»§
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
                IsNewUser = true,
                IsPhoneVerified = false,
                IsEmailVerified = false,
                PhoneNumber = newUser.Phone,
                FirebaseProvider = null
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
                throw new Exception("ThÃ´ng tin Ä‘Äƒng nháº­p khÃ´ng há»£p lá»‡.");
            }

            EnsureUserIsActive(user);
            user.LastLogin = DateTime.UtcNow;
            if (user.FirebaseProvider == "google.com" && user.IsEmailVerified != true)
            {
                user.IsEmailVerified = true;
            }
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
                IsNewUser = false,
                IsPhoneVerified = user.IsVerified == true,
                IsEmailVerified = user.IsEmailVerified == true,
                PhoneNumber = user.Phone,
                FirebaseProvider = user.FirebaseProvider
            };
        }

        public async Task<LoginResponseDto> LoginWithFirebaseAsync(string firebaseToken)
        {
            // 1. XÃ¡c thá»±c Firebase Token
            var (uid, email, name, picture, provider, _) = await _firebaseHelper.VerifyIdToken(firebaseToken);

            var normalizedEmail = string.IsNullOrWhiteSpace(email) ? null : NormalizeEmail(email);
            var existingUser = await _context.Users.FirstOrDefaultAsync(u =>
                u.FirebaseUid == uid ||
                (normalizedEmail != null && u.Email != null && u.Email.ToLower() == normalizedEmail));
            if (existingUser?.IsActive == false)
            {
                throw new Exception("Tai khoan nay da bi khoa hoac vo hieu hoa.");
            }
            
            // Theo nhÆ° yÃªu cáº§u: gá»i SP upsert
            // Äá»‘i sá»‘ cá»§a SP thÆ°á»ng theo thá»© tá»±: uid, email, name, picture
            await _context.Database.ExecuteSqlInterpolatedAsync(
                $"EXEC sp_UpsertFirebaseUser {uid}, {email}, {name}, {picture}, {provider}, {uid}, {firebaseToken}");

            // Load láº¡i User vá»«a Upsert xong
            var user = await _context.Users
                .Include(u => u.Role)
                .Include(u => u.UserPreference)
                .FirstOrDefaultAsync(u => u.FirebaseUid == uid);

            if (user == null)
            {
                throw new Exception("KhÃ´ng thá»ƒ Ä‘á»“ng bá»™ ngÆ°á»i dÃ¹ng tá»« Firebase.");
            }

            EnsureUserIsActive(user);
            user.LastLogin = DateTime.UtcNow;
            if (user.FirebaseProvider == "google.com" && user.IsEmailVerified != true)
            {
                user.IsEmailVerified = true;
            }
            await _context.SaveChangesAsync();

            var token = _jwtHelper.GenerateToken(user);
            var refreshToken = await IssueRefreshTokenAsync(user.UserId);
            
            // Náº¿u lÃ  user má»›i thÃ¬ preference thÆ°á»ng OnboardingDone = false
            bool isNewUser = user.UserPreference == null || user.UserPreference.OnboardingDone != true;

            return new LoginResponseDto
            {
                AccessToken = token,
                RefreshToken = refreshToken,
                UserId = user.UserId,
                FullName = user.FullName,
                Role = user.Role?.RoleName ?? "Tenant",
                IsNewUser = isNewUser,
                IsPhoneVerified = user.IsVerified == true,
                IsEmailVerified = user.IsEmailVerified == true,
                PhoneNumber = user.Phone,
                FirebaseProvider = user.FirebaseProvider
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
                throw new Exception("Refresh token khÃ´ng há»£p lá»‡.");
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
                throw new Exception("Refresh token Ä‘Ã£ háº¿t háº¡n hoáº·c khÃ´ng tá»“n táº¡i.");
            }

            var user = await _context.Users
                .Include(u => u.Role)
                .Include(u => u.UserPreference)
                .FirstOrDefaultAsync(u => u.UserId == provider.UserId && u.IsActive == true);

            if (user == null)
            {
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng há»£p lá»‡ cho refresh token.");
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
                IsNewUser = user.UserPreference == null || user.UserPreference.OnboardingDone != true,
                IsPhoneVerified = user.IsVerified == true,
                IsEmailVerified = user.IsEmailVerified == true,
                PhoneNumber = user.Phone,
                FirebaseProvider = user.FirebaseProvider
            };
        }

        public async Task RequestPasswordResetOtpAsync(ForgotPasswordRequestDto dto)
        {
            var email = NormalizeEmail(dto.Email);
            var user = await FindOrCreatePasswordResetUserAsync(email);

            if (user == null)
            {
                throw new Exception("Email khÃ´ng tá»“n táº¡i trong há»‡ thá»‘ng.");
            }

            if (string.IsNullOrWhiteSpace(user.PasswordHash) && !IsFirebasePasswordUser(user))
            {
                throw new Exception("TÃ i khoáº£n nÃ y Ä‘Äƒng nháº­p báº±ng Google/Facebook, khÃ´ng cáº§n Ä‘áº·t láº¡i máº­t kháº©u táº¡i Ä‘Ã¢y.");
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
                throw new Exception("TÃ i khoáº£n khÃ´ng há»£p lá»‡ Ä‘á»ƒ Ä‘áº·t láº¡i máº­t kháº©u.");
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
                throw new Exception("MÃ£ OTP khÃ´ng Ä‘Ãºng hoáº·c Ä‘Ã£ háº¿t háº¡n.");
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
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng.");
            }

            if (!string.IsNullOrEmpty(user.PasswordHash))
            {
                if (!PasswordHasher.Verify(dto.CurrentPassword, user.PasswordHash))
                {
                    throw new Exception("Máº­t kháº©u hiá»‡n táº¡i khÃ´ng chÃ­nh xÃ¡c.");
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
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng.");
            }

            user.FullName = dto.FullName.Trim();
            user.Phone = dto.Phone?.Trim();
            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        public async Task DeactivateAccountAsync(long userId)
        {
            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("Khong tim thay nguoi dung.");
            }

            user.IsActive = false;
            user.UpdatedAt = DateTime.UtcNow;

            var nowUtc = DateTime.UtcNow;
            var refreshTokens = await _context.SocialAuthProviders
                .Where(p => p.UserId == userId && p.Provider == RefreshProvider)
                .ToListAsync();

            foreach (var refreshToken in refreshTokens)
            {
                refreshToken.TokenExpiresAt = nowUtc.AddSeconds(-1);
                refreshToken.UpdatedAt = nowUtc;
            }

            await _context.SaveChangesAsync();
        }

        private static void EnsureUserIsActive(User user)
        {
            if (user.IsActive == false)
            {
                throw new Exception("Tai khoan nay da bi khoa hoac vo hieu hoa.");
            }
        }

        public async Task<string?> SendPhoneOtpAsync(long userId, string phone)
        {
            if (string.IsNullOrWhiteSpace(phone))
            {
                throw new Exception("Sá»‘ Ä‘iá»‡n thoáº¡i khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.");
            }

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng.");
            }

            // Há»§y cÃ¡c OTP cÅ© chÆ°a sá»­ dá»¥ng cá»§a sá»‘ Ä‘iá»‡n thoáº¡i nÃ y
            var oldOtps = await _context.OtpCodes
                .Where(o => o.Contact == phone
                    && o.OtpType == PhoneVerificationOtpType
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
                UserId = userId,
                Contact = phone,
                OtpType = PhoneVerificationOtpType,
                Code = code,
                IsUsed = false,
                CreatedAt = nowUtc,
                ExpiresAt = nowUtc.AddMinutes(5)
            };

            await _context.OtpCodes.AddAsync(otp);
            await _context.SaveChangesAsync();

            // Gá»­i tin nháº¯n SMS tháº­t qua SmsService
            var message = $"Swings House: Ma OTP xac minh so dien thoai cua ban la {code}. Ma co hieu luc trong 5 phut.";
            var sent = await _smsService.SendSmsAsync(phone, message);
            if (sent)
            {
                return null;
            }

            var requireRealDelivery =
                _configuration.GetValue<bool>("SmsSettings:RequireRealDelivery");
            if (!requireRealDelivery &&
                _environment.EnvironmentName.Equals("Development", StringComparison.OrdinalIgnoreCase))
            {
                return code;
            }

            throw new Exception("KhÃ´ng gá»­i Ä‘Æ°á»£c SMS OTP. Vui lÃ²ng kiá»ƒm tra cáº¥u hÃ¬nh nhÃ  cung cáº¥p SMS.");
        }

        public async Task VerifyPhoneOtpAsync(long userId, string phone, string otpCode)
        {
            if (string.IsNullOrWhiteSpace(phone) || string.IsNullOrWhiteSpace(otpCode))
            {
                throw new Exception("Sá»‘ Ä‘iá»‡n thoáº¡i vÃ  mÃ£ OTP khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.");
            }

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng.");
            }

            var code = otpCode.Trim();
            var nowUtc = DateTime.UtcNow;

            var otp = await _context.OtpCodes
                .Where(o => o.UserId == userId
                    && o.Contact == phone
                    && o.OtpType == PhoneVerificationOtpType
                    && o.Code == code
                    && o.IsUsed != true
                    && o.ExpiresAt > nowUtc)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (otp == null)
            {
                throw new Exception("MÃ£ OTP khÃ´ng Ä‘Ãºng hoáº·c Ä‘Ã£ háº¿t háº¡n.");
            }

            var normalizedPhone = NormalizeVietnamPhone(phone);
            await EnsurePhoneCanBeUsedAsync(userId, normalizedPhone);

            otp.IsUsed = true;
            user.Phone = normalizedPhone;
            user.IsVerified = true; // ÄÃ¡nh dáº¥u Ä‘Ã£ xÃ¡c thá»±c sá»‘ Ä‘iá»‡n thoáº¡i
            user.UpdatedAt = nowUtc;
            await _context.SaveChangesAsync();
        }

        public async Task VerifyPhoneWithFirebaseAsync(long userId, string phone, string firebaseIdToken)
        {
            if (string.IsNullOrWhiteSpace(phone) || string.IsNullOrWhiteSpace(firebaseIdToken))
            {
                throw new Exception("Sá»‘ Ä‘iá»‡n thoáº¡i vÃ  Firebase token khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.");
            }

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng.");
            }

            var (_, _, _, _, _, firebasePhoneNumber) =
                await _firebaseHelper.VerifyIdToken(firebaseIdToken);
            if (string.IsNullOrWhiteSpace(firebasePhoneNumber))
            {
                throw new Exception("Firebase token khÃ´ng pháº£i token xÃ¡c thá»±c sá»‘ Ä‘iá»‡n thoáº¡i.");
            }

            var normalizedInput = NormalizeVietnamPhone(phone);
            var normalizedFirebasePhone = NormalizeVietnamPhone(firebasePhoneNumber);
            if (normalizedInput != normalizedFirebasePhone)
            {
                throw new Exception("Sá»‘ Ä‘iá»‡n thoáº¡i Ä‘Ã£ xÃ¡c thá»±c trÃªn Firebase khÃ´ng khá»›p.");
            }

            await EnsurePhoneCanBeUsedAsync(userId, normalizedInput);

            user.Phone = normalizedInput;
            user.IsVerified = true;
            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        private async Task EnsurePhoneCanBeUsedAsync(long userId, string phone)
        {
            var isUsedByAnotherUser = await _context.Users
                .AnyAsync(u => u.UserId != userId && u.Phone == phone);
            if (isUsedByAnotherUser)
            {
                throw new Exception("Số điện thoại này đã được dùng bởi tài khoản khác.");
            }
        }

        private static string NormalizeVietnamPhone(string phone)
        {
            var normalized = phone.Trim().Replace(" ", "").Replace("-", "");
            if (normalized.StartsWith("+84"))
            {
                return "0" + normalized.Substring(3);
            }

            if (normalized.StartsWith("84") && normalized.Length >= 11)
            {
                return "0" + normalized.Substring(2);
            }

            return normalized;
        }

        public async Task SendEmailOtpAsync(long userId, string email)
        {
            if (string.IsNullOrWhiteSpace(email))
            {
                throw new Exception("Email khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.");
            }

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng.");
            }

            var normalizedEmail = email.Trim().ToLower();

            // Kiá»ƒm tra email Ä‘Ã£ Ä‘Æ°á»£c sá»­ dá»¥ng bá»Ÿi tÃ i khoáº£n khÃ¡c chÆ°a
            var isEmailUsed = await _context.Users
                .AnyAsync(u => u.UserId != userId && u.Email != null && u.Email.ToLower() == normalizedEmail);
            if (isEmailUsed)
            {
                throw new Exception("Email nÃ y Ä‘Ã£ Ä‘Æ°á»£c sá»­ dá»¥ng bá»Ÿi má»™t tÃ i khoáº£n khÃ¡c.");
            }

            // Há»§y cÃ¡c OTP cÅ© chÆ°a sá»­ dá»¥ng cá»§a email nÃ y
            var oldOtps = await _context.OtpCodes
                .Where(o => o.Contact == email
                    && o.OtpType == EmailVerificationOtpType
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
                UserId = userId,
                Contact = email,
                OtpType = EmailVerificationOtpType,
                Code = code,
                IsUsed = false,
                CreatedAt = nowUtc,
                ExpiresAt = nowUtc.AddMinutes(5)
            };

            await _context.OtpCodes.AddAsync(otp);
            await _context.SaveChangesAsync();

            // Gá»­i email tháº­t qua EmailService
            await _emailService.SendEmailVerificationOtpAsync(email, code);
        }

        public async Task VerifyEmailOtpAsync(long userId, string email, string otpCode)
        {
            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(otpCode))
            {
                throw new Exception("Email vÃ  mÃ£ OTP khÃ´ng Ä‘Æ°á»£c Ä‘á»ƒ trá»‘ng.");
            }

            var user = await _context.Users.FindAsync(userId);
            if (user == null)
            {
                throw new Exception("KhÃ´ng tÃ¬m tháº¥y ngÆ°á»i dÃ¹ng.");
            }

            var normalizedEmail = email.Trim().ToLower();
            var code = otpCode.Trim();
            var nowUtc = DateTime.UtcNow;

            var otp = await _context.OtpCodes
                .Where(o => o.UserId == userId
                    && o.Contact == email
                    && o.OtpType == EmailVerificationOtpType
                    && o.Code == code
                    && o.IsUsed != true
                    && o.ExpiresAt > nowUtc)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (otp == null)
            {
                throw new Exception("MÃ£ OTP khÃ´ng Ä‘Ãºng hoáº·c Ä‘Ã£ háº¿t háº¡n.");
            }

            otp.IsUsed = true;
            user.Email = normalizedEmail;
            user.IsEmailVerified = true; // ÄÃ¡nh dáº¥u Ä‘Ã£ xÃ¡c thá»±c email
            user.UpdatedAt = nowUtc;
            await _context.SaveChangesAsync();
        }

    }
}
