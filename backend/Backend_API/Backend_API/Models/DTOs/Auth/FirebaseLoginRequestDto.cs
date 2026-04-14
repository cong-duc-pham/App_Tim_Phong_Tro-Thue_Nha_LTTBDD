namespace Backend_API.Models.DTOs.Auth
{
    public class FirebaseLoginRequestDto
    {
        public string FirebaseToken { get; set; } = null!;
        public string? DeviceToken { get; set; }
    }
}
