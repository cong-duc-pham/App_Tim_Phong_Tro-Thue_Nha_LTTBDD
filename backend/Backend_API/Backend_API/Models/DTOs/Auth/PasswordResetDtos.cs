using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Auth
{
    public class ForgotPasswordRequestDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;
    }

    public class ResetPasswordWithOtpRequestDto
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; } = string.Empty;

        [Required]
        [StringLength(10, MinimumLength = 4)]
        public string OtpCode { get; set; } = string.Empty;

        [Required]
        [MinLength(6)]
        public string NewPassword { get; set; } = string.Empty;
    }

    public class ChangePasswordRequestDto
    {
        [Required]
        public string CurrentPassword { get; set; } = string.Empty;

        [Required]
        [MinLength(6)]
        public string NewPassword { get; set; } = string.Empty;
    }

    public class UpdateProfileRequestDto
    {
        [Required]
        public string FullName { get; set; } = string.Empty;

        public string? Phone { get; set; }
    }
}
