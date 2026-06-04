using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Auth
{
    public class SendPhoneOtpRequestDto
    {
        [Required(ErrorMessage = "Số điện thoại là bắt buộc.")]
        [Phone(ErrorMessage = "Số điện thoại không hợp lệ.")]
        public string Phone { get; set; } = null!;
    }

    public class VerifyPhoneOtpRequestDto
    {
        [Required(ErrorMessage = "Số điện thoại là bắt buộc.")]
        [Phone(ErrorMessage = "Số điện thoại không hợp lệ.")]
        public string Phone { get; set; } = null!;

        [Required(ErrorMessage = "Mã OTP là bắt buộc.")]
        [StringLength(6, MinimumLength = 6, ErrorMessage = "Mã OTP phải có đúng 6 ký tự.")]
        public string OtpCode { get; set; } = null!;
    }
}
