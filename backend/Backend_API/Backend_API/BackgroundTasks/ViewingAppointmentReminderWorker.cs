using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.BackgroundTasks
{
    public class ViewingAppointmentReminderWorker : BackgroundService
    {
        private const string StatusConfirmed = "confirmed";
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<ViewingAppointmentReminderWorker> _logger;

        public ViewingAppointmentReminderWorker(
            IServiceScopeFactory scopeFactory,
            ILogger<ViewingAppointmentReminderWorker> logger)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await SendDueRemindersAsync(stoppingToken);
                    await Task.Delay(TimeSpan.FromMinutes(15), stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Viewing appointment reminder worker failed.");
                    await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
                }
            }
        }

        private async Task SendDueRemindersAsync(CancellationToken ct)
        {
            using var scope = _scopeFactory.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<PhongTroDbContext>();
            var notificationService = scope.ServiceProvider.GetRequiredService<INotificationService>();
            var nowUtc = DateTime.UtcNow;

            await SendReminderWindowAsync(
                context,
                notificationService,
                nowUtc,
                TimeSpan.FromHours(24),
                "appointment_reminder_24h",
                "Lịch xem phòng vào ngày mai",
                ct);

            await SendReminderWindowAsync(
                context,
                notificationService,
                nowUtc,
                TimeSpan.FromHours(2),
                "appointment_reminder_2h",
                "Lịch xem phòng sắp diễn ra",
                ct);
        }

        private async Task SendReminderWindowAsync(
            PhongTroDbContext context,
            INotificationService notificationService,
            DateTime nowUtc,
            TimeSpan leadTime,
            string notificationType,
            string title,
            CancellationToken ct)
        {
            var from = nowUtc.Add(leadTime).AddMinutes(-15);
            var to = nowUtc.Add(leadTime).AddMinutes(15);
            var appointments = await context.ViewingAppointments
                .Include(x => x.Listing)
                .Where(x =>
                    x.Status == StatusConfirmed &&
                    x.ScheduledAt >= from &&
                    x.ScheduledAt < to)
                .ToListAsync(ct);

            foreach (var appointment in appointments)
            {
                var body = $"Bạn có lịch xem \"{appointment.Listing.Title}\" lúc {appointment.ScheduledAt.ToLocalTime():dd/MM/yyyy HH:mm}.";
                await SendOnceAsync(context, notificationService, appointment.AppointmentId, appointment.TenantId, title, body, notificationType, ct);
                await SendOnceAsync(context, notificationService, appointment.AppointmentId, appointment.LandlordId, title, body, notificationType, ct);
            }
        }

        private static async Task SendOnceAsync(
            PhongTroDbContext context,
            INotificationService notificationService,
            long appointmentId,
            long userId,
            string title,
            string body,
            string notificationType,
            CancellationToken ct)
        {
            var alreadySent = await context.Notifications.AnyAsync(x =>
                x.UserId == userId &&
                x.NotifType == notificationType &&
                x.RefType == "viewing_appointment" &&
                x.RefId == appointmentId,
                ct);

            if (!alreadySent)
            {
                await notificationService.CreateAndSendAsync(
                    userId,
                    title,
                    body,
                    notificationType,
                    appointmentId,
                    "viewing_appointment");
            }
        }
    }
}
