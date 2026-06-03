using Backend_API.Models.DTOs.Reviews;

namespace Backend_API.Services.Interfaces
{
    public interface IReviewService
    {
        /// <summary>
        /// Tạo đánh giá mới.
        /// Validate: reviewer không phải chủ sở hữu listing.
        /// </summary>
        Task<ReviewResponseDto> CreateReviewAsync(long reviewerId, long listingId, ReviewCreateDto dto);

        /// <summary>Lấy toàn bộ đánh giá (đã được duyệt) của 1 tin đăng.</summary>
        Task<List<ReviewResponseDto>> GetReviewsByListingAsync(long listingId, long? currentUserId = null);

        /// <summary>
        /// Chủ nhà phản hồi đánh giá.
        /// Validate: chỉ landlord của listing đó mới được reply.
        /// </summary>
        Task<ReviewResponseDto> ReplyReviewAsync(long landlordId, long reviewId, ReviewReplyDto dto);

        /// <summary>Like/unlike một đánh giá. Trả về review sau khi cập nhật.</summary>
        Task<ReviewResponseDto> ToggleLikeAsync(long userId, long reviewId);
    }
}
