using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Auth
{
    public class RefreshTokenRequestDto
    {
        [Required]
        public string RefreshToken { get; set; } = string.Empty;
    }
}
