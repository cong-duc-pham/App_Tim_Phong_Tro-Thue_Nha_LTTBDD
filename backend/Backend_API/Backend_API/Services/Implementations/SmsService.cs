using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
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

        public async Task SendSmsAsync(string phone, string message)
        {
            var smsSection = _configuration.GetSection("SmsSettings");
            var provider = smsSection["Provider"] ?? "Console";

            if (provider.Equals("Console", StringComparison.OrdinalIgnoreCase))
            {
                _logger.LogInformation("[CONSOLE SMS] To: {Phone}, Message: {Message}", phone, message);
                Console.WriteLine($"[CONSOLE SMS] To: {phone}, Message: {message}");
                return;
            }

            if (provider.Equals("SpeedSMS", StringComparison.OrdinalIgnoreCase))
            {
                await SendViaSpeedSmsAsync(phone, message, smsSection.GetSection("SpeedSMS"));
                return;
            }

            if (provider.Equals("Twilio", StringComparison.OrdinalIgnoreCase))
            {
                await SendViaTwilioAsync(phone, message, smsSection.GetSection("Twilio"));
                return;
            }

            _logger.LogWarning("Unknown SMS provider: {Provider}. Falling back to Console.", provider);
            Console.WriteLine($"[CONSOLE SMS FALLBACK] To: {phone}, Message: {message}");
        }

        private async Task SendViaSpeedSmsAsync(string phone, string message, IConfigurationSection config)
        {
            var apiKey = config["ApiKey"];
            var smsTypeStr = config["SmsType"] ?? "2";
            var sender = config["Sender"] ?? "";

            if (string.IsNullOrWhiteSpace(apiKey) || apiKey.Contains("YOUR_SPEEDSMS_API_KEY"))
            {
                _logger.LogWarning("SpeedSMS ApiKey is not configured. Falling back to Console.");
                Console.WriteLine($"[CONSOLE SMS SpeedSMS Mock] To: {phone}, Message: {message}");
                return;
            }

            int smsType = int.TryParse(smsTypeStr, out var parsed) ? parsed : 2;

            // Đảm bảo số điện thoại ở định dạng SpeedSMS hỗ trợ (ví dụ: 849xxx hoặc 09xxx)
            var formattedPhone = phone;
            if (formattedPhone.StartsWith("+84"))
            {
                formattedPhone = "84" + formattedPhone.Substring(3);
            }

            var requestUrl = "https://api.speedsms.vn/index.php/sms/send";
            object requestData;
            if (string.IsNullOrWhiteSpace(sender))
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

            var basicAuthBytes = Encoding.UTF8.GetBytes($"{apiKey}:");
            var basicAuthHeader = Convert.ToBase64String(basicAuthBytes);
            request.Headers.Authorization = new AuthenticationHeaderValue("Basic", basicAuthHeader);

            try
            {
                var response = await _httpClient.SendAsync(request);
                var responseContent = await response.Content.ReadAsStringAsync();
                
                if (response.IsSuccessStatusCode && !responseContent.Contains("\"status\":\"error\""))
                {
                    _logger.LogInformation("SpeedSMS sent successfully to {Phone}. Response: {Response}", phone, responseContent);
                }
                else
                {
                    _logger.LogWarning("SpeedSMS failed to send or returned error. Status: {Status}, Response: {Response}. Falling back to Console.", response.StatusCode, responseContent);
                    Console.WriteLine($"[CONSOLE FALLBACK - SpeedSMS Error] To: {phone}, Message: {message}");
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Error while calling SpeedSMS API. Falling back to Console.");
                Console.WriteLine($"[CONSOLE FALLBACK - SpeedSMS Exception] To: {phone}, Message: {message}");
            }
        }

        private async Task SendViaTwilioAsync(string phone, string message, IConfigurationSection config)
        {
            var accountSid = config["AccountSid"];
            var authToken = config["AuthToken"];
            var fromNumber = config["FromNumber"];

            if (string.IsNullOrWhiteSpace(accountSid) || accountSid.Contains("YOUR_TWILIO_SID") ||
                string.IsNullOrWhiteSpace(authToken) || authToken.Contains("YOUR_TWILIO_TOKEN"))
            {
                _logger.LogWarning("Twilio configurations are not complete. Falling back to Console.");
                Console.WriteLine($"[CONSOLE SMS Twilio Mock] To: {phone}, Message: {message}");
                return;
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
