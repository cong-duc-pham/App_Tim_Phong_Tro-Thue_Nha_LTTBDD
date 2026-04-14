using Backend_API.Models.DTOs.Listings;

namespace Backend_API.Services.Interfaces
{
    public interface IListingService
    {
        /// <summary>Tạo tin đăng mới. Trả về DTO tin đăng vừa tạo.</summary>
        Task<ListingResponseDto> CreateListingAsync(long landlordId, ListingCreateDto dto);

        /// <summary>Cập nhật tin đăng. Chỉ chủ sở hữu mới được phép.</summary>
        Task<ListingResponseDto> UpdateListingAsync(long listingId, ListingUpdateDto dto);

        /// <summary>Xóa tin đăng cùng toàn bộ ảnh trên Firebase Storage.</summary>
        Task DeleteListingAsync(long listingId);

        /// <summary>Lấy chi tiết 1 tin đăng theo ID (bao gồm tiện ích, gói VIP, rating).</summary>
        Task<ListingResponseDto?> GetListingByIdAsync(long listingId);

        /// <summary>
        /// Tìm kiếm / lọc danh sách tin đăng theo nhiều tiêu chí.
        /// Trả về danh sách phân trang kèm tổng số lượng bản ghi.
        /// </summary>
        Task<(List<ListingResponseDto> Items, int TotalCount)> GetListingsAsync(ListingFilterDto filter);

        /// <summary>Lấy tất cả tin đăng của chủ nhà (bao gồm cả tin hết hạn).</summary>
        Task<List<ListingResponseDto>> GetMyListingsAsync(long landlordId);

        /// <summary>Tăng lượt xem tin đăng thêm 1 (fire-and-forget style).</summary>
        Task IncrementViewCountAsync(long listingId);
    }
}
