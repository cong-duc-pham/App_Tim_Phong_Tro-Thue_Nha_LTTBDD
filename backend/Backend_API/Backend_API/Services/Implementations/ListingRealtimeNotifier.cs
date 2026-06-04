using Backend_API.Hubs;
using Backend_API.Services.Interfaces;
using Microsoft.AspNetCore.SignalR;

namespace Backend_API.Services.Implementations
{
    public class ListingRealtimeNotifier : IListingRealtimeNotifier
    {
        private readonly IHubContext<ListingHub> _hubContext;
        private readonly ILogger<ListingRealtimeNotifier> _logger;

        public ListingRealtimeNotifier(
            IHubContext<ListingHub> hubContext,
            ILogger<ListingRealtimeNotifier> logger)
        {
            _hubContext = hubContext;
            _logger = logger;
        }

        public async Task NotifyListingsChangedAsync(long listingId, string action, string? statusName = null)
        {
            try
            {
                await _hubContext.Clients.All.SendAsync("ListingsChanged", new
                {
                    listingId,
                    action,
                    statusName,
                    changedAt = DateTime.UtcNow
                });
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Could not broadcast listing realtime event for listing {ListingId}.", listingId);
            }
        }
    }
}
