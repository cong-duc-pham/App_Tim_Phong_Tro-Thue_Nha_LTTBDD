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
        Task<List<ReviewResponseDto>> GetReviewsByListingAsync(long listingId);

        /// <summary>
        /// Chủ nhà phản hồi đánh giá.
        /// Validate: chỉ landlord của listing đó mới được reply.
        /// </summary>
        Task<ReviewResponseDto> ReplyReviewAsync(long landlordId, long reviewId, ReviewReplyDto dto);
    }
}
