using System.Collections.Generic;
using System.Threading.Tasks;
using Backend_API.Models.DTOs.Reviews;

namespace Backend_API.Services.Interfaces
{
    public interface IReviewService
    {
        /// <summary>
        /// Tạo đánh giá hoặc hỏi đáp mới.
        /// Validate: reviewer không phải chủ sở hữu listing nếu là review.
        /// </summary>
        Task<ReviewResponseDto> CreateReviewAsync(long reviewerId, long listingId, ReviewCreateDto dto);

        /// <summary>Lấy toàn bộ đánh giá hoặc hỏi đáp (đã được duyệt) của 1 tin đăng.</summary>
        Task<List<ReviewResponseDto>> GetReviewsByListingAsync(long listingId, string? type = null, long? currentUserId = null);

        Task<List<ReviewResponseDto>> GetMyReviewsAsync(long reviewerId);

        Task<ReviewResponseDto> UpdateReviewAsync(long reviewerId, long reviewId, ReviewUpdateDto dto);

        Task DeleteReviewAsync(long reviewerId, long reviewId);

        Task<ReviewResponseDto> ReportReviewAsync(long userId, long reviewId);

        /// <summary>
        /// Chủ nhà phản hồi đánh giá.
        /// Validate: chỉ landlord của listing đó mới được reply.
        /// </summary>
        Task<ReviewResponseDto> ReplyReviewAsync(long landlordId, long reviewId, ReviewReplyDto dto);

        /// <summary>Like/unlike một đánh giá. Trả về review sau khi cập nhật.</summary>
        Task<ReviewResponseDto> ToggleLikeAsync(long userId, long reviewId);
    }
}
