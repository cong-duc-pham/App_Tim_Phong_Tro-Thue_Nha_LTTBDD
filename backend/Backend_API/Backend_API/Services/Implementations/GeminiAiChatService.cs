using System.Net.Http.Json;
using System.Text.Json;
using Backend_API.Models.DTOs.Ai;
using Backend_API.Services.Interfaces;

namespace Backend_API.Services.Implementations
{
    public class GeminiAiChatService : IAiChatService
    {
        private const string DefaultInstructions =
            "Ban la tro ly AI cua ung dung Swings House, chuyen ho tro tim phong tro tai Viet Nam. " +
            "Hay tra loi bang tieng Viet tu nhien, ngan gon va thuc te. " +
            "Ho tro nguoi dung xac dinh ngan sach, khu vuc, tien ich, kiem tra tin dang, " +
            "lap danh sach cau hoi cho chu nha va luu y an toan khi dat coc. " +
            "Khong duoc khang dinh mot phong con trong, gia chinh xac hay thong tin phap ly " +
            "neu khong co du lieu. Khong thay the tu van phap ly hoac tai chinh chuyen nghiep.";

        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;
        private readonly ILogger<GeminiAiChatService> _logger;

        public GeminiAiChatService(
            HttpClient httpClient,
            IConfiguration configuration,
            ILogger<GeminiAiChatService> logger)
        {
            _httpClient = httpClient;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<AiChatResponseDto> ReplyAsync(
            AiChatRequestDto request,
            CancellationToken cancellationToken = default)
        {
            var apiKey = Environment.GetEnvironmentVariable("GEMINI_API_KEY")
                         ?? _configuration["AiChat:Gemini:ApiKey"]
                         ?? _configuration["Translation:Gemini:ApiKey"];
            if (string.IsNullOrWhiteSpace(apiKey))
            {
                throw new InvalidOperationException(
                    "AI chat is not configured. Set the GEMINI_API_KEY environment variable.");
            }

            var baseUrl = _configuration["AiChat:Gemini:BaseUrl"]
                          ?? _configuration["Translation:Gemini:BaseUrl"]
                          ?? "https://generativelanguage.googleapis.com/v1beta";
            var model = _configuration["AiChat:Gemini:Model"]
                        ?? _configuration["Translation:Gemini:Model"]
                        ?? "gemini-2.5-flash";
            var timeoutSeconds = int.TryParse(
                _configuration["AiChat:Gemini:TimeoutSeconds"],
                out var parsedTimeout)
                ? parsedTimeout
                : 45;

            _httpClient.BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/");
            _httpClient.Timeout = TimeSpan.FromSeconds(timeoutSeconds);
            _httpClient.DefaultRequestHeaders.Remove("x-goog-api-key");
            _httpClient.DefaultRequestHeaders.Add("x-goog-api-key", apiKey);

            var contents = request.Messages
                .Where(message => !string.IsNullOrWhiteSpace(message.Content))
                .TakeLast(20)
                .Select(message => new
                {
                    role = message.Role == "assistant" ? "model" : "user",
                    parts = new[]
                    {
                        new { text = message.Content.Trim() }
                    }
                })
                .ToArray();

            var payload = new
            {
                systemInstruction = new
                {
                    parts = new[]
                    {
                        new
                        {
                            text = _configuration["AiChat:Gemini:Instructions"]
                                   ?? DefaultInstructions
                        }
                    }
                },
                contents,
                generationConfig = new
                {
                    temperature = 0.4,
                    maxOutputTokens = 350
                }
            };

            using var response = await _httpClient.PostAsJsonAsync(
                $"models/{model}:generateContent",
                payload,
                cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
                _logger.LogWarning(
                    "Gemini chat request failed with status {StatusCode}: {ErrorBody}",
                    response.StatusCode,
                    errorBody.Length > 1000 ? errorBody[..1000] : errorBody);
                throw new HttpRequestException(
                    "The AI provider could not answer right now.",
                    null,
                    response.StatusCode);
            }

            using var document = await JsonDocument.ParseAsync(
                await response.Content.ReadAsStreamAsync(cancellationToken),
                cancellationToken: cancellationToken);

            var reply = ExtractReply(document.RootElement);
            if (string.IsNullOrWhiteSpace(reply))
            {
                throw new InvalidOperationException("The AI provider returned an empty response.");
            }

            return new AiChatResponseDto
            {
                Reply = reply.Trim(),
                Model = model
            };
        }

        private static string ExtractReply(JsonElement root)
        {
            if (!root.TryGetProperty("candidates", out var candidates)
                || candidates.ValueKind != JsonValueKind.Array
                || candidates.GetArrayLength() == 0)
            {
                return string.Empty;
            }

            var firstCandidate = candidates[0];
            if (!firstCandidate.TryGetProperty("content", out var content)
                || !content.TryGetProperty("parts", out var parts)
                || parts.ValueKind != JsonValueKind.Array)
            {
                return string.Empty;
            }

            var textParts = parts.EnumerateArray()
                .Where(part => part.TryGetProperty("text", out _))
                .Select(part => part.GetProperty("text").GetString())
                .Where(text => !string.IsNullOrWhiteSpace(text));

            return string.Join("\n", textParts);
        }
    }
}
