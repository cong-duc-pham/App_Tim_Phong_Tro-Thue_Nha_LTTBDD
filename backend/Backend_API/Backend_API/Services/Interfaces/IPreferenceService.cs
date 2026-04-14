using Backend_API.Models.DTOs.Users;

namespace Backend_API.Services.Interfaces
{
    public interface IPreferenceService
    {
        /// <summary>
        /// Tạo mới hoặc cập nhật Preference của User (Upsert).
        /// </summary>
        Task<UserPreferenceDto> SavePreferencesAsync(long userId, UserPreferenceDto dto);

        /// <summary>
        /// Lấy Preference hiện tại của User. Trả về null nếu chưa có.
        /// </summary>
        Task<UserPreferenceDto?> GetPreferencesAsync(long userId);
    }
}
