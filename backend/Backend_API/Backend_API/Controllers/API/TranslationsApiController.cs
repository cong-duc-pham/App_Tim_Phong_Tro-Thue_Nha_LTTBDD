using Backend_API.Models.DTOs.Translations;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace Backend_API.Controllers.API
{
    [ApiController]
    [Route("api/translations")]
    [Tags("Translations")]
    public class TranslationsApiController : ControllerBase
    {
        private readonly ITranslationService _translationService;

        public TranslationsApiController(ITranslationService translationService)
        {
            _translationService = translationService;
        }

        [HttpPost("listing")]
        [ProducesResponseType(typeof(ListingTranslationResponseDto), StatusCodes.Status200OK)]
        public async Task<IActionResult> TranslateListing(
            [FromBody] ListingTranslationRequestDto request,
            CancellationToken cancellationToken)
        {
            var result = await _translationService.TranslateListingAsync(request, cancellationToken);
            return Ok(result);
        }
    }
}
