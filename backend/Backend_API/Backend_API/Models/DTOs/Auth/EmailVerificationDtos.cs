using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Auth
{
    public class SendEmailOtpRequestDto
    {
        [Required(ErrorMessage = "Email là bắt buộc.")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
        public string Email { get; set; } = null!;
    }

    public class VerifyEmailOtpRequestDto
    {
        [Required(ErrorMessage = "Email là bắt buộc.")]
        [EmailAddress(ErrorMessage = "Email không hợp lệ.")]
        public string Email { get; set; } = null!;

        [Required(ErrorMessage = "Mã OTP là bắt buộc.")]
        [StringLength(6, MinimumLength = 6, ErrorMessage = "Mã OTP phải có đúng 6 ký tự.")]
        public string OtpCode { get; set; } = null!;
    }
}
