using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Storage
{
    public class GenerateSignedUploadUrlRequestDto
    {
        [Required]
        [MaxLength(255)]
        public string FileName { get; set; } = string.Empty;

        [MaxLength(100)]
        public string? ContentType { get; set; }

        /// <summary>
        /// Dung cho listing: cover hoặc gallery.
        /// </summary>
        [MaxLength(20)]
        public string? UploadType { get; set; }

        [Range(1, 60)]
        public int? ExpiresInMinutes { get; set; }
    }

    public class SignedUploadUrlResponseDto
    {
        public string UploadUrl { get; set; } = string.Empty;

        public string DownloadUrl { get; set; } = string.Empty;

        public string StoragePath { get; set; } = string.Empty;

        public int MaxFileSizeMb { get; set; }

        public string RequiredContentTypePrefix { get; set; } = string.Empty;

        /// <summary>
        /// Cloudinary unsigned upload preset.
        /// </summary>
        public string? UploadPreset { get; set; }

        /// <summary>
        /// Cloudinary public_id được backend định nghĩa trước để giữ cấu trúc thư mục.
        /// </summary>
        public string? PublicId { get; set; }
    }
}
