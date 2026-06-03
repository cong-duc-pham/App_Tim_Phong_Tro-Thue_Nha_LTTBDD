using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Backend_API.Models.DTOs.Translations;
using Backend_API.Services.Interfaces;

namespace Backend_API.Services.Implementations
{
    public class XaiTranslationService : ITranslationService
    {
        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;
        private readonly ILogger<XaiTranslationService> _logger;

        public XaiTranslationService(
            HttpClient httpClient,
            IConfiguration configuration,
            ILogger<XaiTranslationService> logger)
        {
            _httpClient = httpClient;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<ListingTranslationResponseDto> TranslateListingAsync(
            ListingTranslationRequestDto request,
            CancellationToken cancellationToken = default)
        {
            var targetLanguage = string.IsNullOrWhiteSpace(request.TargetLanguage)
                ? "English"
                : request.TargetLanguage.Trim();

            if (!targetLanguage.Equals("English", StringComparison.OrdinalIgnoreCase)
                && !targetLanguage.Equals("en", StringComparison.OrdinalIgnoreCase))
            {
                return Original(request, isTranslated: false);
            }

            var apiKey = Environment.GetEnvironmentVariable("XAI_API_KEY")
                         ?? _configuration["Translation:Xai:ApiKey"];
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                return Original(request, isTranslated: false);
            }

            var baseUrl = _configuration["Translation:Xai:BaseUrl"] ?? "https://api.x.ai/v1";
            var model = _configuration["Translation:Xai:Model"] ?? "grok-4.3";
            var timeoutSeconds = int.TryParse(
                _configuration["Translation:Xai:TimeoutSeconds"],
                out var parsedTimeout)
                ? parsedTimeout
                : 30;

            _httpClient.BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/");
            _httpClient.Timeout = TimeSpan.FromSeconds(timeoutSeconds);
            _httpClient.DefaultRequestHeaders.Authorization =
                new AuthenticationHeaderValue("Bearer", apiKey);

            var sourceJson = JsonSerializer.Serialize(new
            {
                request.Title,
                request.Description,
                request.StreetAddress,
                request.TypeName,
                request.AmenityNames
            });

            var payload = new
            {
                model,
                stream = false,
                temperature = 0,
                messages = new[]
                {
                    new
                    {
                        role = "system",
                        content =
                            "You translate Vietnamese rental listing data into natural English. " +
                            "Keep numbers, addresses, place names, units, and brand names recognizable. " +
                            "Return only compact JSON with keys: title, description, streetAddress, typeName, amenityNames."
                    },
                    new
                    {
                        role = "user",
                        content = sourceJson
                    }
                }
            };

            try
            {
                using var response = await _httpClient.PostAsJsonAsync(
                    "chat/completions",
                    payload,
                    cancellationToken);

                if (!response.IsSuccessStatusCode)
                {
                    _logger.LogWarning(
                        "xAI translation failed with status {StatusCode}",
                        response.StatusCode);
                    return Original(request, isTranslated: false);
                }

                using var document = await JsonDocument.ParseAsync(
                    await response.Content.ReadAsStreamAsync(cancellationToken),
                    cancellationToken: cancellationToken);

                var content = document.RootElement
                    .GetProperty("choices")[0]
                    .GetProperty("message")
                    .GetProperty("content")
                    .GetString();

                if (string.IsNullOrWhiteSpace(content))
                {
                    return Original(request, isTranslated: false);
                }

                return ParseTranslation(content, request);
            }
            catch (Exception ex) when (ex is HttpRequestException
                                      || ex is TaskCanceledException
                                      || ex is JsonException
                                      || ex is InvalidOperationException
                                      || ex is KeyNotFoundException)
            {
                _logger.LogWarning(ex, "Could not translate listing data with xAI.");
                return Original(request, isTranslated: false);
            }
        }

        private static ListingTranslationResponseDto ParseTranslation(
            string content,
            ListingTranslationRequestDto original)
        {
            var cleaned = content.Trim();
            if (cleaned.StartsWith("```", StringComparison.Ordinal))
            {
                cleaned = cleaned.Trim('`').Trim();
                if (cleaned.StartsWith("json", StringComparison.OrdinalIgnoreCase))
                {
                    cleaned = cleaned[4..].Trim();
                }
            }

            using var translated = JsonDocument.Parse(cleaned);
            var root = translated.RootElement;

            return new ListingTranslationResponseDto
            {
                Title = ReadString(root, "title") ?? original.Title,
                Description = ReadString(root, "description") ?? original.Description,
                StreetAddress = ReadString(root, "streetAddress") ?? original.StreetAddress,
                TypeName = ReadString(root, "typeName") ?? original.TypeName,
                AmenityNames = ReadStringList(root, "amenityNames", original.AmenityNames),
                IsTranslated = true
            };
        }

        private static string? ReadString(JsonElement root, string name)
        {
            return root.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
                ? value.GetString()
                : null;
        }

        private static List<string> ReadStringList(
            JsonElement root,
            string name,
            List<string> fallback)
        {
            if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Array)
            {
                return fallback;
            }

            return value.EnumerateArray()
                .Where(item => item.ValueKind == JsonValueKind.String)
                .Select(item => item.GetString())
                .Where(item => !string.IsNullOrWhiteSpace(item))
                .Select(item => item!)
                .ToList();
        }

        private static ListingTranslationResponseDto Original(
            ListingTranslationRequestDto request,
            bool isTranslated)
        {
            return new ListingTranslationResponseDto
            {
                Title = request.Title,
                Description = request.Description,
                StreetAddress = request.StreetAddress,
                TypeName = request.TypeName,
                AmenityNames = request.AmenityNames,
                IsTranslated = isTranslated
            };
        }
    }
}
