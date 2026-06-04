using System.Text.Json;
using System.Text.Json.Serialization;

namespace Backend_API.Models.DTOs.Payment
{
    public class PayOsCreatePaymentLinkResult
    {
        public string CheckoutUrl { get; set; } = string.Empty;
        public string PaymentLinkId { get; set; } = string.Empty;
        public string QrCode { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public JsonElement RawResponse { get; set; }
    }

    public class PayOsPaymentLinkInfoResult
    {
        public string Status { get; set; } = string.Empty;
        public decimal AmountPaid { get; set; }
        public decimal AmountRemaining { get; set; }
        public JsonElement RawResponse { get; set; }
    }

    public class PayOsWebhookDto
    {
        [JsonPropertyName("code")]
        public string Code { get; set; } = string.Empty;

        [JsonPropertyName("desc")]
        public string Desc { get; set; } = string.Empty;

        [JsonPropertyName("success")]
        public bool Success { get; set; }

        [JsonPropertyName("data")]
        public JsonElement Data { get; set; }

        [JsonPropertyName("signature")]
        public string Signature { get; set; } = string.Empty;
    }
}
