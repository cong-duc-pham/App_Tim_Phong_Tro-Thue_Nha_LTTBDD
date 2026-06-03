using Backend_API.Models.DTOs.Translations;

namespace Backend_API.Services.Interfaces
{
    public interface ITranslationService
    {
        Task<ListingTranslationResponseDto> TranslateListingAsync(
            ListingTranslationRequestDto request,
            CancellationToken cancellationToken = default);
    }
}
