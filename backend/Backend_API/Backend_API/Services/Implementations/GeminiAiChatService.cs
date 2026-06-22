using System.Net;
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

                if (response.StatusCode == HttpStatusCode.TooManyRequests)
                {
                    return new AiChatResponseDto
                    {
                        Reply = BuildFallbackReply(request),
                        Model = "local-fallback"
                    };
                }

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

        private static string BuildFallbackReply(AiChatRequestDto request)
        {
            var latestMessage = request.Messages
                .LastOrDefault(message =>
                    message.Role == "user"
                    && !string.IsNullOrWhiteSpace(message.Content))
                ?.Content
                .Trim()
                .ToLowerInvariant() ?? string.Empty;

            if (ContainsAny(latestMessage, "tiêu chí", "tieu chi", "phù hợp", "phu hop", "ngân sách", "ngan sach"))
            {
                return """
                    Bạn có thể lập tiêu chí tìm phòng theo 6 nhóm:

                    1. Ngân sách: tiền thuê tối đa và tổng chi phí điện, nước, Internet, gửi xe.
                    2. Khu vực: khoảng cách đến nơi học/làm và thời gian di chuyển chấp nhận được.
                    3. Loại phòng: diện tích, ở một mình hay ở ghép, có gác hoặc nội thất.
                    4. Tiện ích: điều hòa, máy giặt, bếp, chỗ để xe và giờ giấc.
                    5. An toàn: khóa cửa, camera, lối thoát hiểm và tình trạng ngập.
                    6. Hợp đồng: tiền cọc, thời hạn thuê, điều kiện hoàn cọc và tăng giá.

                    Hãy ưu tiên 3 tiêu chí bắt buộc, sau đó mới đến các tiêu chí mong muốn.
                    """;
            }

            if (ContainsAny(latestMessage, "đặt cọc", "dat coc", "chủ nhà", "chu nha", "hợp đồng", "hop dong"))
            {
                return """
                    Trước khi đặt cọc, bạn nên hỏi rõ:

                    - Tổng tiền thuê và từng khoản phí hằng tháng.
                    - Số tiền cọc, điều kiện hoàn cọc và trường hợp bị khấu trừ.
                    - Thời hạn thuê, ngày thanh toán và mức phạt trả phòng sớm.
                    - Quy định về khách, giờ giấc, nấu ăn, vật nuôi và gửi xe.
                    - Ai chịu chi phí sửa chữa thiết bị khi hư hỏng.
                    - Người nhận cọc có phải chủ nhà hoặc người được ủy quyền không.

                    Chỉ chuyển tiền sau khi xem phòng, kiểm tra giấy tờ và nhận phiếu cọc có chữ ký.
                    """;
            }

            if (ContainsAny(latestMessage, "đáng ngờ", "dang ngo", "lừa đảo", "lua dao", "an toàn", "an toan"))
            {
                return """
                    Một tin đăng có thể đáng ngờ nếu giá thấp bất thường, từ chối cho xem phòng, thúc giục chuyển cọc hoặc dùng ảnh không khớp địa chỉ.

                    Bạn nên:

                    - Tìm ngược hình ảnh và kiểm tra địa chỉ trên bản đồ.
                    - Xem phòng trực tiếp hoặc gọi video theo thời gian thực.
                    - Đối chiếu giấy tờ người cho thuê và quyền cho thuê.
                    - Không gửi CCCD đầy đủ hoặc mã OTP.
                    - Không chuyển tiền nếu chưa có thỏa thuận cọc rõ ràng.
                    """;
            }

            if (ContainsAny(latestMessage, "khu vực", "khu vuc", "quận", "quan", "đi lại", "di lai"))
            {
                return """
                    Khi chọn khu vực, hãy so sánh thời gian đi lại vào giờ cao điểm, tuyến xe buýt, tình trạng ngập, an ninh và các tiện ích gần phòng.

                    Nên chọn 2-3 khu vực thay thế trong cùng bán kính, rồi so sánh tổng chi phí thuê với chi phí và thời gian di chuyển mỗi tháng.
                    """;
            }

            return """
                Mình đang tạm thời hoạt động ở chế độ hỗ trợ cơ bản. Bạn hãy cung cấp:

                - Khu vực muốn thuê.
                - Ngân sách tối đa mỗi tháng.
                - Số người ở.
                - Diện tích hoặc loại phòng.
                - Tiện ích bắt buộc.
                - Ngày dự kiến chuyển vào.

                Từ đó mình sẽ giúp bạn lập danh sách tiêu chí và các câu hỏi cần kiểm tra trước khi thuê.
                """;
        }

        private static bool ContainsAny(string text, params string[] keywords)
        {
            return keywords.Any(keyword =>
                text.Contains(keyword, StringComparison.OrdinalIgnoreCase));
        }
    }
}
