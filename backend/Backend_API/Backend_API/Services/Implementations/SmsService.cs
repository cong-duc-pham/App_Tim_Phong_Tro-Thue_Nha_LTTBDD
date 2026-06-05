using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Backend_API.Services.Interfaces;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Backend_API.Services.Implementations
{
    public class SmsService : ISmsService
    {
        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;
        private readonly ILogger<SmsService> _logger;

        public SmsService(
            HttpClient httpClient,
            IConfiguration configuration,
            ILogger<SmsService> logger)
        {
            _httpClient = httpClient;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task<bool> SendSmsAsync(string phone, string message)
        {
            var smsSection = _configuration.GetSection("SmsSettings");
            var provider = smsSection["Provider"] ?? "Console";

            if (provider.Equals("Console", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogInformation("[CONSOLE SMS] To: {Phone}, Message: {Message}", phone, message);
                Console.WriteLine($"[CONSOLE SMS] To: {phone}, Message: {message}");
                return false;
            }

            if (provider.Equals("SpeedSMS", StringComparison.OrdinalIgnoreCase))
            {
                return await SendViaSpeedSmsAsync(phone, message, smsSection.GetSection("SpeedSMS"));
            }

            if (provider.Equals("ESMS", StringComparison.OrdinalIgnoreCase))
            {
                return await SendViaESmsAsync(phone, message, smsSection.GetSection("ESMS"));
            }

            if (provider.Equals("Stringee", StringComparison.OrdinalIgnoreCase))
            {
                return await SendViaStringeeAsync(phone, message, smsSection.GetSection("Stringee"));
            }

            if (provider.Equals("Twilio", StringComparison.OrdinalIgnoreCase))
            {
                return await SendViaTwilioAsync(phone, message, smsSection.GetSection("Twilio"));
            }

            _logger.LogWarning("Unknown SMS provider: {Provider}. Falling back to Console.", provider);
            Console.WriteLine($"[CONSOLE SMS FALLBACK] To: {phone}, Message: {message}");
            return false;
        }

        private async Task<bool> SendViaSpeedSmsAsync(string phone, string message, IConfigurationSection config)
        {
            var apiKey = config["ApiKey"];
            var smsTypeStr = config["SmsType"] ?? "2";
            var sender = config["Sender"] ?? "";

            if (string.IsNullOrWhiteSpace(apiKey) || apiKey.Contains("YOUR_SPEEDSMS_API_KEY"))
            {
                _logger.LogWarning("SpeedSMS ApiKey is not configured. Falling back to Console.");
                Console.WriteLine($"[CONSOLE SMS SpeedSMS Mock] To: {phone}, Message: {message}");
                return false;
            }

            int smsType = int.TryParse(smsTypeStr, out var parsed) ? parsed : 2;

            // SpeedSMS hỗ trợ số Việt Nam dạng 09x/03x...; chuẩn hóa +84/84 về 0 để hạn chế lỗi 105.
            var formattedPhone = phone;
            if (formattedPhone.StartsWith("+84"))
            {
                formattedPhone = "0" + formattedPhone.Substring(3);
            }
            else if (formattedPhone.StartsWith("84") && formattedPhone.Length >= 11)
            {
                formattedPhone = "0" + formattedPhone.Substring(2);
            }

            var requestUrl = "https://api.speedsms.vn/index.php/sms/send";
            object requestData;
            if (string.IsNullOrWhiteSpace(sender) || smsType == 4)
            {
                requestData = new
                {
                    to = new[] { formattedPhone },
                    content = message,
                    sms_type = smsType
                };
            }
            else
            {
                requestData = new
                {
                    to = new[] { formattedPhone },
                    content = message,
                    sms_type = smsType,
                    sender = sender
                };
            }

            var jsonPayload = JsonSerializer.Serialize(requestData);
            Console.WriteLine($"[DEBUG SpeedSMS Payload] {jsonPayload}");
            using var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
            request.Content = new StringContent(jsonPayload, Encoding.UTF8, "application/json");

            var basicAuthBytes = Encoding.UTF8.GetBytes($"{apiKey}:x");
            var basicAuthHeader = Convert.ToBase64String(basicAuthBytes);
            request.Headers.Authorization = new AuthenticationHeaderValue("Basic", basicAuthHeader);

            try
            {
                var response = await _httpClient.SendAsync(request);
                var responseContent = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode && !responseContent.Contains("\"status\":\"error\""))
                {
                    _logger.LogInformation("SpeedSMS sent successfully to {Phone}. Response: {Response}", phone, responseContent);
                    return true;
                }

                var errorMessage = ExtractSpeedSmsError(responseContent);
                _logger.LogError(
                    "SpeedSMS failed. HTTP status: {Status}, API error: {Error}, Response: {Response}",
                    response.StatusCode,
                    errorMessage,
                    responseContent);
                throw new Exception($"SpeedSMS gửi OTP thất bại: {errorMessage}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while calling SpeedSMS API.");
                throw;
            }
        }

        private static string ExtractSpeedSmsError(string responseContent)
        {
            try
            {
                using var document = JsonDocument.Parse(responseContent);
                var root = document.RootElement;
                var code = root.TryGetProperty("code", out var codeElement)
                    ? codeElement.GetString()
                    : null;
                var message = root.TryGetProperty("message", out var messageElement)
                    ? messageElement.GetString()
                    : null;

                if (message != null &&
                    message.Contains("sender not found", StringComparison.OrdinalIgnoreCase))
                {
                    return "Tài khoản SpeedSMS chưa được cấp sender/brandname để gửi SMS. Hãy kích hoạt Verify/Notify, đăng ký brandname, hoặc dùng SMS Android app với deviceId hợp lệ.";
                }

                if (!string.IsNullOrWhiteSpace(code) || !string.IsNullOrWhiteSpace(message))
                {
                    return $"code {code ?? "unknown"} - {message ?? "unknown error"}";
                }
            }
            catch
            {
                // Response không phải JSON hợp lệ; dùng raw content bên dưới.
            }

            return string.IsNullOrWhiteSpace(responseContent)
                ? "Không có nội dung lỗi từ SpeedSMS."
                : responseContent;
        }

        private async Task<bool> SendViaESmsAsync(string phone, string message, IConfigurationSection config)
        {
            var apiKey = config["ApiKey"];
            var secretKey = config["SecretKey"];
            var smsType = config["SmsType"] ?? "8";
            var brandname = config["Brandname"];
            var sandbox = config["Sandbox"] ?? "0";

            if (string.IsNullOrWhiteSpace(apiKey) || string.IsNullOrWhiteSpace(secretKey) ||
                apiKey.Contains("YOUR_ESMS_API_KEY", StringComparison.OrdinalIgnoreCase) ||
                secretKey.Contains("YOUR_ESMS_SECRET_KEY", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogWarning("eSMS ApiKey/SecretKey is not configured. Falling back to Console.");
                Console.WriteLine($"[CONSOLE SMS eSMS Mock] To: {phone}, Message: {message}");
                return false;
            }

            var requestData = new Dictionary<string, string>
            {
                { "ApiKey", apiKey },
                { "SecretKey", secretKey },
                { "Phone", NormalizeVietnamPhone(phone) },
                { "Content", message },
                { "SmsType", smsType },
                { "Sandbox", sandbox }
            };

            if (!string.IsNullOrWhiteSpace(brandname))
            {
                requestData["Brandname"] = brandname;
            }

            using var request = new HttpRequestMessage(
                HttpMethod.Post,
                "https://rest.esms.vn/MainService.svc/json/SendMultipleMessage_V4_post_json/");
            request.Content = new StringContent(
                JsonSerializer.Serialize(requestData),
                Encoding.UTF8,
                "application/json");

            try
            {
                var response = await _httpClient.SendAsync(request);
                var responseContent = await response.Content.ReadAsStringAsync();
                var (isSuccess, errorMessage) = ParseESmsResponse(responseContent);

                if (response.IsSuccessStatusCode && isSuccess)
                {
                    _logger.LogInformation("eSMS sent successfully to {Phone}. Response: {Response}", phone, responseContent);
                    return true;
                }

                _logger.LogError(
                    "eSMS failed. HTTP status: {Status}, API error: {Error}, Response: {Response}",
                    response.StatusCode,
                    errorMessage,
                    responseContent);
                throw new Exception($"eSMS gui OTP that bai: {errorMessage}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while calling eSMS API.");
                throw;
            }
        }

        private static string NormalizeVietnamPhone(string phone)
        {
            var formattedPhone = phone.Trim().Replace(" ", "").Replace("-", "");
            if (formattedPhone.StartsWith("+84"))
            {
                return "0" + formattedPhone.Substring(3);
            }

            if (formattedPhone.StartsWith("84") && formattedPhone.Length >= 11)
            {
                return "0" + formattedPhone.Substring(2);
            }

            return formattedPhone;
        }

        private static (bool IsSuccess, string ErrorMessage) ParseESmsResponse(string responseContent)
        {
            try
            {
                using var document = JsonDocument.Parse(responseContent);
                var root = document.RootElement;
                var code = GetJsonValue(root, "CodeResult");
                var error = GetJsonValue(root, "ErrorMessage");
                var message = GetJsonValue(root, "Message");

                if (code == "100")
                {
                    return (true, string.Empty);
                }

                if (code == "103")
                {
                    return (false, "Tai khoan eSMS khong du tien de gui SMS. Vui long nap tien va doi eSMS cap nhat so du roi thu lai.");
                }

                var detail = !string.IsNullOrWhiteSpace(error)
                    ? error
                    : !string.IsNullOrWhiteSpace(message)
                        ? message
                        : "unknown error";

                return (false, $"code {code ?? "unknown"} - {detail}");
            }
            catch
            {
                return (false, string.IsNullOrWhiteSpace(responseContent)
                    ? "Khong co noi dung loi tu eSMS."
                    : responseContent);
            }
        }

        private static string? GetJsonValue(JsonElement root, string propertyName)
        {
            if (!root.TryGetProperty(propertyName, out var element))
            {
                return null;
            }

            return element.ValueKind switch
            {
                JsonValueKind.String => element.GetString(),
                JsonValueKind.Number => element.GetRawText(),
                JsonValueKind.True => "true",
                JsonValueKind.False => "false",
                _ => element.ToString()
            };
        }

        private async Task<bool> SendViaStringeeAsync(string phone, string message, IConfigurationSection config)
        {
            var apiSid = config["ApiSid"];
            var apiSecret = config["ApiSecret"];
            var brandname = config["Brandname"];

            if (string.IsNullOrWhiteSpace(apiSid) || string.IsNullOrWhiteSpace(apiSecret) ||
                apiSid.Contains("YOUR_STRINGEE_API_SID", StringComparison.OrdinalIgnoreCase) ||
                apiSecret.Contains("YOUR_STRINGEE_API_SECRET", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogWarning("Stringee ApiSid/ApiSecret is not configured. Falling back to Console.");
                Console.WriteLine($"[CONSOLE SMS Stringee Mock] To: {phone}, Message: {message}");
                return false;
            }

            if (string.IsNullOrWhiteSpace(brandname))
            {
                throw new Exception("Stringee chua co Brandname/Sender ID de gui SMS. Hay cau hinh SmsSettings:Stringee:Brandname theo brandname duoc Stringee cap.");
            }

            var requestData = new
            {
                sms = new[]
                {
                    new
                    {
                        from = brandname,
                        to = NormalizeVietnamPhoneInternational(phone),
                        text = message
                    }
                }
            };

            using var request = new HttpRequestMessage(HttpMethod.Post, "https://api.stringee.com/v1/sms");
            request.Content = new StringContent(
                JsonSerializer.Serialize(requestData),
                Encoding.UTF8,
                "application/json");
            request.Headers.Add("X-STRINGEE-AUTH", CreateStringeeRestJwt(apiSid, apiSecret));
            request.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            try
            {
                var response = await _httpClient.SendAsync(request);
                var responseContent = await response.Content.ReadAsStringAsync();
                var (isSuccess, errorMessage) = ParseStringeeSmsResponse(responseContent);

                if (response.IsSuccessStatusCode && isSuccess)
                {
                    _logger.LogInformation("Stringee SMS sent successfully to {Phone}. Response: {Response}", phone, responseContent);
                    return true;
                }

                _logger.LogError(
                    "Stringee SMS failed. HTTP status: {Status}, API error: {Error}, Response: {Response}",
                    response.StatusCode,
                    errorMessage,
                    responseContent);
                throw new Exception($"Stringee gui OTP that bai: {errorMessage}");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while calling Stringee SMS API.");
                throw;
            }
        }

        private static string NormalizeVietnamPhoneInternational(string phone)
        {
            var formattedPhone = NormalizeVietnamPhone(phone);
            if (formattedPhone.StartsWith("0"))
            {
                return "84" + formattedPhone.Substring(1);
            }

            if (formattedPhone.StartsWith("+"))
            {
                return formattedPhone.Substring(1);
            }

            return formattedPhone;
        }

        private static string CreateStringeeRestJwt(string apiSid, string apiSecret)
        {
            var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            var header = new Dictionary<string, object>
            {
                { "alg", "HS256" },
                { "cty", "stringee-api;v=1" }
            };
            var payload = new Dictionary<string, object>
            {
                { "jti", $"{apiSid}-{now}" },
                { "iss", apiSid },
                { "exp", now + 3600 },
                { "rest_api", 1 }
            };

            var encodedHeader = Base64UrlEncode(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(header)));
            var encodedPayload = Base64UrlEncode(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload)));
            var unsignedToken = $"{encodedHeader}.{encodedPayload}";

            using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(apiSecret));
            var signature = Base64UrlEncode(hmac.ComputeHash(Encoding.UTF8.GetBytes(unsignedToken)));
            return $"{unsignedToken}.{signature}";
        }

        private static string Base64UrlEncode(byte[] bytes)
        {
            return Convert.ToBase64String(bytes)
                .TrimEnd('=')
                .Replace('+', '-')
                .Replace('/', '_');
        }

        private static (bool IsSuccess, string ErrorMessage) ParseStringeeSmsResponse(string responseContent)
        {
            try
            {
                using var document = JsonDocument.Parse(responseContent);
                var root = document.RootElement;

                if (root.TryGetProperty("smsSent", out var smsSentElement) &&
                    smsSentElement.TryGetInt32(out var smsSent) &&
                    smsSent > 0 &&
                    root.TryGetProperty("result", out var resultElement) &&
                    resultElement.ValueKind == JsonValueKind.Array &&
                    resultElement.GetArrayLength() > 0)
                {
                    var firstResult = resultElement[0];
                    var resultCode = GetJsonValue(firstResult, "r");
                    var resultMessage = GetJsonValue(firstResult, "msg");
                    if (resultCode == "0")
                    {
                        return (true, string.Empty);
                    }

                    if (resultCode == "1" &&
                        resultMessage != null &&
                        resultMessage.Contains("From number invalid", StringComparison.OrdinalIgnoreCase))
                    {
                        return (false, "Tai khoan Stringee chua co SMS Brandname/Number lam nguoi gui. Hay them Number/Brandname trong Stringee hoac chuyen sang Stringee Verify Voice OTP.");
                    }

                    return (false, $"code {resultCode ?? "unknown"} - {resultMessage ?? "unknown error"}");
                }

                var code = GetJsonValue(root, "r") ?? GetJsonValue(root, "code");
                var message = GetJsonValue(root, "msg") ?? GetJsonValue(root, "message");
                if (!string.IsNullOrWhiteSpace(code) || !string.IsNullOrWhiteSpace(message))
                {
                    if (code == "1" &&
                        message != null &&
                        message.Contains("From number invalid", StringComparison.OrdinalIgnoreCase))
                    {
                        return (false, "Tai khoan Stringee chua co SMS Brandname/Number lam nguoi gui. Hay them Number/Brandname trong Stringee hoac chuyen sang Stringee Verify Voice OTP.");
                    }

                    return (false, $"code {code ?? "unknown"} - {message ?? "unknown error"}");
                }
            }
            catch
            {
                return (false, string.IsNullOrWhiteSpace(responseContent)
                    ? "Khong co noi dung loi tu Stringee."
                    : responseContent);
            }

            return (false, string.IsNullOrWhiteSpace(responseContent)
                ? "Khong co noi dung loi tu Stringee."
                : responseContent);
        }

        private async Task<bool> SendViaTwilioAsync(string phone, string message, IConfigurationSection config)
        {
            var accountSid = config["AccountSid"];
            var authToken = config["AuthToken"];
            var fromNumber = config["FromNumber"];

            if (string.IsNullOrWhiteSpace(accountSid) || accountSid.Contains("YOUR_TWILIO_SID") ||
                string.IsNullOrWhiteSpace(authToken) || authToken.Contains("YOUR_TWILIO_TOKEN"))
            {
                _logger.LogWarning("Twilio configurations are not complete. Falling back to Console.");
                Console.WriteLine($"[CONSOLE SMS Twilio Mock] To: {phone}, Message: {message}");
                return false;
            }

            // Twilio yêu cầu sđt định dạng E.164 (bắt đầu bằng +)
            var formattedPhone = phone;
            if (!formattedPhone.StartsWith("+"))
            {
                if (formattedPhone.StartsWith("0"))
                {
                    formattedPhone = "+84" + formattedPhone.Substring(1);
                }
                else
                {
                    formattedPhone = "+" + formattedPhone;
                }
            }

            var requestUrl = $"https://api.twilio.com/2010-04-01/Accounts/{accountSid}/Messages.json";

            var requestParams = new Dictionary<string, string>
            {
                { "To", formattedPhone },
                { "From", fromNumber ?? "" },
                { "Body", message }
            };

            using var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
            request.Content = new FormUrlEncodedContent(requestParams);

            var basicAuthBytes = Encoding.UTF8.GetBytes($"{accountSid}:{authToken}");
            var basicAuthHeader = Convert.ToBase64String(basicAuthBytes);
            request.Headers.Authorization = new AuthenticationHeaderValue("Basic", basicAuthHeader);

            try
            {
                var response = await _httpClient.SendAsync(request);
                var responseContent = await response.Content.ReadAsStringAsync();

                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation("Twilio sent successfully to {Phone}. Response: {Response}", phone, responseContent);
                    return true;
                }
                else
                {
                    _logger.LogError("Twilio failed to send. Status: {Status}, Response: {Response}", response.StatusCode, responseContent);
                    throw new Exception($"Twilio API returned error: {responseContent}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error while calling Twilio API");
                throw;
            }
        }
    }
}
