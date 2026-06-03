using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Reviews
{
    public class ReviewCreateDto
    {
        [Required]
        [Range(1, 5)]
        public byte Rating { get; set; }

        public string? Comment { get; set; }

        // Đánh giá chi tiết theo từng tiêu chí (1-5, optional)
        [Range(1, 5)] public byte? RatingLocation  { get; set; }
        [Range(1, 5)] public byte? RatingPrice      { get; set; }
        [Range(1, 5)] public byte? RatingCleanness  { get; set; }
        [Range(1, 5)] public byte? RatingSecurity   { get; set; }

        // Firebase Storage URLs của ảnh (Flutter upload xong gửi URL lên)
        public List<string> ImageUrls { get; set; } = new();
    }

    public class ReviewReplyDto
    {
        [Required]
        [MinLength(1)]
        public string Reply { get; set; } = null!;
    }

    public class ReviewResponseDto
    {
        public long   ReviewId         { get; set; }
        public long   ReviewerId       { get; set; }
        public string ReviewerName     { get; set; } = null!;
        public string? ReviewerAvatar  { get; set; }

        public byte  Rating            { get; set; }
        public string? Comment         { get; set; }

        public byte? RatingLocation    { get; set; }
        public byte? RatingPrice       { get; set; }
        public byte? RatingCleanness   { get; set; }
        public byte? RatingSecurity    { get; set; }

        public bool? IsApproved        { get; set; }
        public string? LandlordReply   { get; set; }
        public DateTime? RepliedAt     { get; set; }
        public DateTime? CreatedAt     { get; set; }
        public int LikeCount           { get; set; }
        public bool IsLiked            { get; set; }

        public List<string> ImageUrls  { get; set; } = new();
    }
}
