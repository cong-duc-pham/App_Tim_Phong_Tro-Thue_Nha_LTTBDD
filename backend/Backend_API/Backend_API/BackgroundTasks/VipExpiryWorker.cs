using Backend_API.Helpers;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Data.Common;

namespace Backend_API.BackgroundTasks
{
    public class VipExpiryWorker : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<VipExpiryWorker> _logger;

        public VipExpiryWorker(IServiceScopeFactory scopeFactory, ILogger<VipExpiryWorker> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("VipExpiryWorker is starting.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var delay = GetDelayUntilNextMidnight();
                    _logger.LogInformation("VipExpiryWorker sleeping for {Delay} before next run.", delay);
                    await Task.Delay(delay, stoppingToken);

                    await RunDailyTasksAsync(stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "VipExpiryWorker failed while executing daily tasks.");
                }
            }

            _logger.LogInformation("VipExpiryWorker is stopping.");
        }

        private static TimeSpan GetDelayUntilNextMidnight()
        {
            var now = DateTime.Now;
            var next = now.Date.AddDays(1);
            return next - now;
        }

        private async Task RunDailyTasksAsync(CancellationToken ct)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<PhongTroDbContext>();
            var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
            var storageHelper = scope.ServiceProvider.GetRequiredService<CloudinaryStorageHelper>();

            var nowUtc = DateTime.UtcNow;

            await ProcessExpiredVipPackagesAsync(context, notificationService, nowUtc, ct);
            await SendVipExpiringWarningsAsync(context, notificationService, nowUtc, ct);
            await CleanupOrphanStorageFilesAsync(context, storageHelper, ct);
        }

        // Task 1: Hạ cấp gói hết hạn
        private async Task ProcessExpiredVipPackagesAsync(
            PhongTroDbContext context,
            INotificationService notificationService,
            DateTime nowUtc,
            CancellationToken ct)
        {
            var expiredPackages = await context.ListingPostPackages
                .Include(lpp => lpp.Listing)
                .Include(lpp => lpp.Package)
                .Where(lpp => lpp.IsActive == true && lpp.EndDate <= nowUtc)
                .ToListAsync(ct);

            if (expiredPackages.Count == 0)
            {
                _logger.LogInformation("VipExpiryWorker Task1: no expired VIP package.");
                return;
            }

            foreach (var item in expiredPackages)
            {
                item.IsActive = false;
            }

            var affectedListingIds = expiredPackages
                .Select(x => x.ListingId)
                .Distinct()
                .ToList();

            var affectedListings = await context.Listings
                .Where(l => affectedListingIds.Contains(l.ListingId))
                .ToListAsync(ct);

            foreach (var listing in affectedListings)
            {
                var stillFeatured = await context.ListingPostPackages
                    .Include(p => p.Package)
                    .AnyAsync(p =>
                        p.ListingId == listing.ListingId &&
                        p.IsActive == true &&
                        p.EndDate > nowUtc &&
                        p.Package.IsHighlighted, ct);

                listing.IsFeatured = stillFeatured;
                listing.UpdatedAt = nowUtc;
            }

            await context.SaveChangesAsync(ct);

            foreach (var item in expiredPackages)
            {
                await notificationService.CreateAndSendAsync(
                    item.Listing.LandlordId,
                    "Gói VIP đã hết hạn",
                    $"Gói {item.Package.PackageName} cho tin \"{item.Listing.Title}\" đã hết hạn.",
                    "vip_expired",
                    item.ListingId,
                    "listing");
            }

            _logger.LogInformation("VipExpiryWorker Task1: processed {Count} expired package(s).", expiredPackages.Count);
        }

        // Task 2: Cảnh báo sắp hết hạn (còn 3 ngày)
        private async Task SendVipExpiringWarningsAsync(
            PhongTroDbContext context,
            INotificationService notificationService,
            DateTime nowUtc,
            CancellationToken ct)
        {
            var warningDate = nowUtc.Date.AddDays(3);

            var expiringPackages = await context.ListingPostPackages
                .Include(lpp => lpp.Listing)
                .Include(lpp => lpp.Package)
                .Where(lpp =>
                    lpp.IsActive == true &&
                    lpp.EndDate > nowUtc &&
                    lpp.EndDate.Date == warningDate)
                .ToListAsync(ct);

            foreach (var item in expiringPackages)
            {
                await notificationService.CreateAndSendAsync(
                    item.Listing.LandlordId,
                    "Gói VIP sắp hết hạn",
                    $"Gói {item.Package.PackageName} cho tin \"{item.Listing.Title}\" sẽ hết hạn sau 3 ngày. Gia hạn ngay!",
                    "vip_expiring_3d",
                    item.ListingId,
                    "listing");
            }

            _logger.LogInformation("VipExpiryWorker Task2: sent {Count} warning notification(s).", expiringPackages.Count);
        }

        // Task 3: Dọn file Cloudinary mồ côi
        private async Task CleanupOrphanStorageFilesAsync(
            PhongTroDbContext context,
            CloudinaryStorageHelper storageHelper,
            CancellationToken ct)
        {
            var orphans = new List<(long FileId, string PublicId)>();
            var conn = context.Database.GetDbConnection();
            var shouldClose = false;
            if (conn.State != System.Data.ConnectionState.Open)
            {
                await conn.OpenAsync(ct);
                shouldClose = true;
            }

            await using var cmd = conn.CreateCommand();
            cmd.CommandText = "EXEC sp_GetOrphanCloudinaryFiles";
            await using var reader = await cmd.ExecuteReaderAsync(ct);

            var fileIdOrdinal = TryGetOrdinal(reader, "file_id")
                ?? TryGetOrdinal(reader, "FileId")
                ?? throw new Exception("sp_GetOrphanCloudinaryFiles thiếu cột file_id/FileId.");

            var publicIdOrdinal = TryGetOrdinal(reader, "public_id")
                ?? TryGetOrdinal(reader, "PublicId")
                ?? throw new Exception("sp_GetOrphanCloudinaryFiles thiếu cột public_id/PublicId.");

            while (await reader.ReadAsync(ct))
            {
                var fileId = reader.GetInt64(fileIdOrdinal);
                var publicId = reader.GetString(publicIdOrdinal);
                orphans.Add((fileId, publicId));
            }

            if (shouldClose)
            {
                await conn.CloseAsync();
            }

            foreach (var item in orphans)
            {
                await storageHelper.DeleteFileAsync(item.PublicId);

                var record = await context.CloudinaryFiles
                    .FirstOrDefaultAsync(f => f.FileId == item.FileId, ct);

                if (record != null)
                {
                    context.CloudinaryFiles.Remove(record);
                }
            }

            await context.SaveChangesAsync(ct);

            _logger.LogInformation("VipExpiryWorker Task3: cleaned {Count} orphan file record(s).", orphans.Count);
        }

        private static int? TryGetOrdinal(DbDataReader reader, string columnName)
        {
            for (var i = 0; i < reader.FieldCount; i++)
            {
                if (string.Equals(reader.GetName(i), columnName, StringComparison.OrdinalIgnoreCase))
                {
                    return i;
                }
            }

            return null;
        }
    }
}
