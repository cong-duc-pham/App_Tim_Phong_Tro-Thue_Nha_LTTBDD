namespace Backend_API.Models.DTOs.Auth
{
    public class LoginResponseDto
    {
        public string AccessToken { get; set; } = null!;
        public string RefreshToken { get; set; } = null!;
        public long UserId { get; set; }
        public string FullName { get; set; } = null!;
        public string Role { get; set; } = null!;
        public bool IsNewUser { get; set; }
        public bool IsPhoneVerified { get; set; }
        public bool IsEmailVerified { get; set; }
        public string? PhoneNumber { get; set; }
        public string? FirebaseProvider { get; set; }
    }
}
