namespace Backend_API.Services.Interfaces
{
    public interface IListingRealtimeNotifier
    {
        Task NotifyListingsChangedAsync(long listingId, string action, string? statusName = null);
    }
}
