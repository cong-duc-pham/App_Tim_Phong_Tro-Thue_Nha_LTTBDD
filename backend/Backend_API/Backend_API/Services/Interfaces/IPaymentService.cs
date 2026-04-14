using Backend_API.Models.DTOs.Payment;

namespace Backend_API.Services.Interfaces
{
    public interface IPaymentService
    {
        Task<List<PackageListDto>> GetPackagesAsync();
        Task<InvoiceResponseDto> CreateInvoiceAsync(long landlordId, long listingId, int packageId);
        Task ProcessPaymentCallbackAsync(string transactionRef, string gateway);
        Task<List<InvoiceResponseDto>> GetMyInvoicesAsync(long landlordId);
    }
}
