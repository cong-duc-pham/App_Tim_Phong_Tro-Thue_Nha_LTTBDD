namespace Backend_API.Models.DTOs.Translations
{
    public class ListingTranslationRequestDto
    {
        public string TargetLanguage { get; set; } = "English";
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? StreetAddress { get; set; }
        public string? TypeName { get; set; }
        public List<string> AmenityNames { get; set; } = new();
    }

    public class ListingTranslationResponseDto
    {
        public string? Title { get; set; }
        public string? Description { get; set; }
        public string? StreetAddress { get; set; }
        public string? TypeName { get; set; }
        public List<string> AmenityNames { get; set; } = new();
        public bool IsTranslated { get; set; }
        public string Provider { get; set; } = "Google Gemini";
    }
}
