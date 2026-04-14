using Backend_API.Models.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Backend_API.BackgroundTasks
{
    public class DailyStatsJob : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<DailyStatsJob> _logger;

        public DailyStatsJob(IServiceScopeFactory scopeFactory, ILogger<DailyStatsJob> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("DailyStatsJob is starting.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var delay = GetDelayUntilNextRun();
                    _logger.LogInformation("DailyStatsJob sleeping for {Delay} before next run.", delay);
                    await Task.Delay(delay, stoppingToken);
                    await UpsertYesterdayStatsAsync(stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "DailyStatsJob failed while generating statistics.");
                }
            }

            _logger.LogInformation("DailyStatsJob is stopping.");
        }

        private static TimeSpan GetDelayUntilNextRun()
        {
            var now = DateTime.Now;
            var next = now.Date.AddDays(1).AddMinutes(5);
            return next <= now ? TimeSpan.FromMinutes(1) : next - now;
        }

        private async Task UpsertYesterdayStatsAsync(CancellationToken ct)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<PhongTroDbContext>();

            var targetDateUtc = DateTime.UtcNow.Date.AddDays(-1);
            var dayStart = targetDateUtc;
            var dayEnd = targetDateUtc.AddDays(1);
            var statDate = DateOnly.FromDateTime(targetDateUtc);

            var activeListingStatusIds = await context.ListingStatuses
                .Where(s => s.StatusName == "active" || s.StatusName == "pending")
                .Select(s => s.StatusId)
                .ToListAsync(ct);

            var newUsers = await context.Users
                .CountAsync(u => u.CreatedAt != null && u.CreatedAt >= dayStart && u.CreatedAt < dayEnd, ct);

            var newUsersFirebase = await context.Users
                .CountAsync(u =>
                    u.CreatedAt != null &&
                    u.CreatedAt >= dayStart &&
                    u.CreatedAt < dayEnd &&
                    !string.IsNullOrEmpty(u.FirebaseUid), ct);

            var newListings = await context.Listings
                .CountAsync(l => l.CreatedAt != null && l.CreatedAt >= dayStart && l.CreatedAt < dayEnd, ct);

            var totalRevenue = await context.Payments
                .Include(p => p.Status)
                .Where(p =>
                    p.PaidAt != null &&
                    p.PaidAt >= dayStart &&
                    p.PaidAt < dayEnd &&
                    p.Status.StatusName == "success")
                .SumAsync(p => (decimal?)p.Amount, ct) ?? 0m;

            var totalSearches = await context.SearchHistories
                .CountAsync(s => s.SearchedAt != null && s.SearchedAt >= dayStart && s.SearchedAt < dayEnd, ct);

            var activeListings = activeListingStatusIds.Count == 0
                ? 0
                : await context.Listings.CountAsync(l => activeListingStatusIds.Contains(l.StatusId), ct);

            var fcmSentCount = await context.Notifications
                .CountAsync(n => n.SentAt != null && n.SentAt >= dayStart && n.SentAt < dayEnd && n.FcmStatus == "sent", ct);

            var fcmFailedCount = await context.Notifications
                .CountAsync(n => n.SentAt != null && n.SentAt >= dayStart && n.SentAt < dayEnd && n.FcmStatus == "failed", ct);

            var cloudinaryUploads = await context.CloudinaryFiles
                .Where(f => f.CreatedAt != null && f.CreatedAt >= dayStart && f.CreatedAt < dayEnd)
                .ToListAsync(ct);

            var cloudinaryUploadCount = cloudinaryUploads.Count;
            var cloudinaryUploadMb = (cloudinaryUploads.Sum(f => (decimal?)(f.FileSizeKb ?? 0)) ?? 0m) / 1024m;
            var cloudinaryDeleteCount = await context.CloudinaryFiles
                .CountAsync(f => f.DeletedAt != null && f.DeletedAt >= dayStart && f.DeletedAt < dayEnd, ct);

            var existing = await context.DailyStats.FirstOrDefaultAsync(x => x.StatDate == statDate, ct);
            if (existing == null)
            {
                existing = new DailyStat
                {
                    StatDate = statDate,
                    CreatedAt = DateTime.UtcNow
                };
                await context.DailyStats.AddAsync(existing, ct);
            }

            existing.NewUsers = newUsers;
            existing.NewUsersFirebase = newUsersFirebase;
            existing.NewListings = newListings;
            existing.TotalRevenue = totalRevenue;
            existing.TotalSearches = totalSearches;
            existing.ActiveListings = activeListings;
            existing.FcmSentCount = fcmSentCount;
            existing.FcmFailedCount = fcmFailedCount;
            existing.CloudinaryUploadCount = cloudinaryUploadCount;
            existing.CloudinaryUploadMb = Math.Round(cloudinaryUploadMb, 2);
            existing.CloudinaryDeleteCount = cloudinaryDeleteCount;

            await context.SaveChangesAsync(ct);
            _logger.LogInformation("DailyStatsJob upserted stats for {StatDate}.", statDate);
        }
    }
}
