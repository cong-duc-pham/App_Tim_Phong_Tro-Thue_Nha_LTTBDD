using Backend_API.Models.DTOs.Payment;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using System.Globalization;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;

namespace Backend_API.Services.Implementations
{
    public class PayOsService : IPayOsService
    {
        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;

        public PayOsService(HttpClient httpClient, IConfiguration configuration)
        {
            _httpClient = httpClient;
            _configuration = configuration;
        }

        public async Task<PayOsCreatePaymentLinkResult> CreatePaymentLinkAsync(
            Invoice invoice,
            PostPackage package,
            CancellationToken cancellationToken = default)
        {
            var clientId = GetRequiredConfig("PayOS:ClientId", "PAYOS_CLIENT_ID");
            var apiKey = GetRequiredConfig("PayOS:ApiKey", "PAYOS_API_KEY");
            var checksumKey = GetRequiredConfig("PayOS:ChecksumKey", "PAYOS_CHECKSUM_KEY");
            var returnUrl = GetRequiredConfig("PayOS:ReturnUrl", "PAYOS_RETURN_URL");
            var cancelUrl = GetRequiredConfig("PayOS:CancelUrl", "PAYOS_CANCEL_URL");

            var orderCode = checked((int)invoice.InvoiceId);
            var amount = decimal.ToInt32(decimal.Round(invoice.TotalAmount, 0));
            var description = BuildDescription(invoice.InvoiceId);
            var signaturePayload =
                $"amount={amount}&cancelUrl={cancelUrl}&description={description}&orderCode={orderCode}&returnUrl={returnUrl}";

            var request = new
            {
                orderCode,
                amount,
                description,
                items = new[]
                {
                    new
                    {
                        name = package.PackageName,
                        quantity = 1,
                        price = amount
                    }
                },
                cancelUrl,
                returnUrl,
                expiredAt = new DateTimeOffset(DateTime.UtcNow.AddMinutes(30)).ToUnixTimeSeconds(),
                signature = Sign(signaturePayload, checksumKey)
            };

            using var httpRequest = new HttpRequestMessage(
                HttpMethod.Post,
                "https://api-merchant.payos.vn/v2/payment-requests")
            {
                Content = JsonContent.Create(request)
            };
            httpRequest.Headers.TryAddWithoutValidation("x-client-id", clientId);
            httpRequest.Headers.TryAddWithoutValidation("x-api-key", apiKey);

            using var response = await _httpClient.SendAsync(httpRequest, cancellationToken);
            var responseText = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                throw new Exception($"PayOS tạo link thất bại ({(int)response.StatusCode}): {responseText}");
            }

            using var document = JsonDocument.Parse(responseText);
            var root = document.RootElement.Clone();
            var code = root.TryGetProperty("code", out var codeElement)
                ? codeElement.GetString()
                : null;
            if (!string.Equals(code, "00", StringComparison.OrdinalIgnoreCase))
            {
                var desc = root.TryGetProperty("desc", out var descElement)
                    ? descElement.GetString()
                    : responseText;
                throw new Exception($"PayOS tạo link thất bại: {desc}");
            }

            var data = root.GetProperty("data");
            return new PayOsCreatePaymentLinkResult
            {
                CheckoutUrl = ReadString(data, "checkoutUrl"),
                PaymentLinkId = ReadString(data, "paymentLinkId"),
                QrCode = ReadString(data, "qrCode"),
                Status = ReadString(data, "status"),
                RawResponse = root
            };
        }

        public async Task<PayOsPaymentLinkInfoResult> GetPaymentLinkInfoAsync(
            long orderCode,
            CancellationToken cancellationToken = default)
        {
            var clientId = GetRequiredConfig("PayOS:ClientId", "PAYOS_CLIENT_ID");
            var apiKey = GetRequiredConfig("PayOS:ApiKey", "PAYOS_API_KEY");

            using var httpRequest = new HttpRequestMessage(
                HttpMethod.Get,
                $"https://api-merchant.payos.vn/v2/payment-requests/{orderCode}");
            httpRequest.Headers.TryAddWithoutValidation("x-client-id", clientId);
            httpRequest.Headers.TryAddWithoutValidation("x-api-key", apiKey);

            using var response = await _httpClient.SendAsync(httpRequest, cancellationToken);
            var responseText = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                throw new Exception($"PayOS kiem tra thanh toan that bai ({(int)response.StatusCode}): {responseText}");
            }

            using var document = JsonDocument.Parse(responseText);
            var root = document.RootElement.Clone();
            var code = root.TryGetProperty("code", out var codeElement)
                ? codeElement.GetString()
                : null;
            if (!string.Equals(code, "00", StringComparison.OrdinalIgnoreCase))
            {
                var desc = root.TryGetProperty("desc", out var descElement)
                    ? descElement.GetString()
                    : responseText;
                throw new Exception($"PayOS kiem tra thanh toan that bai: {desc}");
            }

            var data = root.GetProperty("data");
            return new PayOsPaymentLinkInfoResult
            {
                Status = ReadString(data, "status"),
                AmountPaid = ReadDecimal(data, "amountPaid"),
                AmountRemaining = ReadDecimal(data, "amountRemaining"),
                RawResponse = root
            };
        }

        public bool VerifyWebhookData(JsonElement data, string signature)
        {
            if (string.IsNullOrWhiteSpace(signature))
            {
                return false;
            }

            var checksumKey = GetRequiredConfig("PayOS:ChecksumKey", "PAYOS_CHECKSUM_KEY");
            var payload = BuildSortedQueryString(data);
            var expected = Sign(payload, checksumKey);
            return CryptographicOperations.FixedTimeEquals(
                Encoding.UTF8.GetBytes(expected.ToLowerInvariant()),
                Encoding.UTF8.GetBytes(signature.ToLowerInvariant()));
        }

        private string GetRequiredConfig(string configKey, string envKey)
        {
            var value = Environment.GetEnvironmentVariable(envKey)
                ?? _configuration[configKey];
            if (string.IsNullOrWhiteSpace(value))
            {
                throw new InvalidOperationException($"Thiếu cấu hình PayOS: {configKey} hoặc {envKey}.");
            }

            return value.Trim();
        }

        private static string BuildDescription(long invoiceId)
        {
            var value = $"VIP{invoiceId}";
            return value.Length <= 9 ? value : value[..9];
        }

        private static string Sign(string data, string checksumKey)
        {
            using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(checksumKey));
            var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        private static string BuildSortedQueryString(JsonElement data)
        {
            var values = new SortedDictionary<string, string>(StringComparer.Ordinal);
            foreach (var property in data.EnumerateObject())
            {
                values[property.Name] = ConvertJsonValue(property.Value);
            }

            return string.Join("&", values.Select(item => $"{item.Key}={item.Value}"));
        }

        private static string ConvertJsonValue(JsonElement value)
        {
            return value.ValueKind switch
            {
                JsonValueKind.Null or JsonValueKind.Undefined => string.Empty,
                JsonValueKind.String => NormalizeNullableText(value.GetString()),
                JsonValueKind.Number => value.GetRawText(),
                JsonValueKind.True => "True",
                JsonValueKind.False => "False",
                JsonValueKind.Array => JsonSerializer.Serialize(
                    value.EnumerateArray().Select(SortObjectIfNeeded).ToArray(),
                    JsonOptions),
                JsonValueKind.Object => JsonSerializer.Serialize(SortObject(value), JsonOptions),
                _ => value.ToString()
            };
        }

        private static object? SortObjectIfNeeded(JsonElement value)
        {
            return value.ValueKind == JsonValueKind.Object
                ? SortObject(value)
                : JsonSerializer.Deserialize<object>(value.GetRawText());
        }

        private static SortedDictionary<string, object?> SortObject(JsonElement value)
        {
            var result = new SortedDictionary<string, object?>(StringComparer.Ordinal);
            foreach (var property in value.EnumerateObject())
            {
                result[property.Name] = property.Value.ValueKind switch
                {
                    JsonValueKind.Null or JsonValueKind.Undefined => null,
                    JsonValueKind.Object => SortObject(property.Value),
                    JsonValueKind.Array => property.Value.EnumerateArray()
                        .Select(SortObjectIfNeeded)
                        .ToArray(),
                    JsonValueKind.Number => property.Value.TryGetInt64(out var longValue)
                        ? longValue
                        : property.Value.GetDecimal(),
                    JsonValueKind.True => true,
                    JsonValueKind.False => false,
                    JsonValueKind.String => property.Value.GetString(),
                    _ => property.Value.ToString()
                };
            }

            return result;
        }

        private static string NormalizeNullableText(string? value)
        {
            return value is null or "null" or "undefined" ? string.Empty : value;
        }

        private static string ReadString(JsonElement data, string property)
        {
            return data.TryGetProperty(property, out var value)
                ? value.GetString() ?? string.Empty
                : string.Empty;
        }

        private static decimal ReadDecimal(JsonElement data, string property)
        {
            if (!data.TryGetProperty(property, out var value))
            {
                return 0;
            }

            if (value.ValueKind == JsonValueKind.Number && value.TryGetDecimal(out var result))
            {
                return result;
            }

            return decimal.TryParse(value.ToString(), out var parsed) ? parsed : 0;
        }

        private static readonly JsonSerializerOptions JsonOptions = new()
        {
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
            WriteIndented = false
        };
    }
}
