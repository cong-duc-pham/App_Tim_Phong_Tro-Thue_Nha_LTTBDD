using Backend_API.Models.DTOs.Payment;
using Backend_API.Models.Entities;
using System.Text.Json;

namespace Backend_API.Services.Interfaces
{
    public interface IPayOsService
    {
        Task<PayOsCreatePaymentLinkResult> CreatePaymentLinkAsync(
            Invoice invoice,
            PostPackage package,
            CancellationToken cancellationToken = default);

        Task<PayOsPaymentLinkInfoResult> GetPaymentLinkInfoAsync(
            long orderCode,
            CancellationToken cancellationToken = default);

        bool VerifyWebhookData(JsonElement data, string signature);
    }
}
