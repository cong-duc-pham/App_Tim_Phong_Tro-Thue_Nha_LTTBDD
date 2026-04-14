using Backend_API.Models.DTOs.Listings;

namespace Backend_API.Services.Interfaces
{
    public interface IFavoriteService
    {
        /// <summary>
        /// Toggle yêu thích: Thêm nếu chưa có, xóa nếu đã có.
        /// Trả về true nếu sau thao tác tin đang được yêu thích, false nếu đã bỏ.
        /// </summary>
        Task<bool> ToggleFavoriteAsync(long userId, long listingId);

        /// <summary>Lấy danh sách tất cả tin đã lưu của một user.</summary>
        Task<List<ListingResponseDto>> GetFavoritesAsync(long userId);

        /// <summary>Kiểm tra user có đang yêu thích tin đăng này không.</summary>
        Task<bool> IsFavoriteAsync(long userId, long listingId);
    }
}
