using Backend_API.Models.DTOs.Auth;
using System.Threading.Tasks;

namespace Backend_API.Services.Interfaces
{
    public interface IAuthService
    {
        Task<LoginResponseDto> RegisterAsync(RegisterRequestDto dto);
        
        Task<LoginResponseDto> LoginAsync(LoginRequestDto dto);
        
        Task<LoginResponseDto> LoginWithFirebaseAsync(string firebaseToken);
        
        Task UpdateFcmTokenAsync(long userId, string token);
        
        Task<LoginResponseDto> RefreshTokenAsync(string refreshToken);

        Task RequestPasswordResetOtpAsync(ForgotPasswordRequestDto dto);

        Task ResetPasswordWithOtpAsync(ResetPasswordWithOtpRequestDto dto);

        Task ChangePasswordAsync(long userId, ChangePasswordRequestDto dto);

        Task UpdateProfileAsync(long userId, UpdateProfileRequestDto dto);
    }
}
