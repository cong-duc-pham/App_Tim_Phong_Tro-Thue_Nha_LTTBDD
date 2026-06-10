using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Ai
{
    public class AiChatMessageDto
    {
        [Required]
        [RegularExpression("^(user|assistant)$")]
        public string Role { get; set; } = "user";

        [Required]
        [StringLength(4000)]
        public string Content { get; set; } = string.Empty;
    }

    public class AiChatRequestDto
    {
        [Required]
        [MinLength(1)]
        [MaxLength(20)]
        public List<AiChatMessageDto> Messages { get; set; } = [];
    }

    public class AiChatResponseDto
    {
        public string Reply { get; set; } = string.Empty;
        public string Model { get; set; } = string.Empty;
    }
}
