using System.Collections.Generic;
using System.Threading.Tasks;
using Backend_API.Models.DTOs.Rentals;

namespace Backend_API.Services.Interfaces
{
    public interface IRentalService
    {
        Task<RentalResponseDto> CreateRentalAsync(long landlordId, long listingId, RentalCreateDto dto);
        Task<List<RentalResponseDto>> GetMyTenantsAsync(long landlordId);
        Task<List<RentalResponseDto>> GetMyRentedRoomsAsync(long tenantId);
        Task<RentalResponseDto> ConfirmRentalFromChatAsync(long landlordId, long convId);
        Task<RentalResponseDto> EndRentalFromChatAsync(long landlordId, long convId);
        Task EnsureRentalsAndUpgradeReviewsTableAsync();
    }
}
