using Backend_API.Models.DTOs.Appointments;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class ViewingAppointmentService : IViewingAppointmentService
    {
        private const string StatusPending = "pending";
        private const string StatusConfirmed = "confirmed";
        private const string StatusDeclined = "declined";
        private const string StatusCancelled = "cancelled";
        private const string ActiveListingStatus = "active";
        private const int SlotStartHour = 8;
        private const int SlotEndHour = 20;
        private const int SlotIntervalMinutes = 30;
        private const int SlotConflictWindowMinutes = 30;

        private readonly PhongTroDbContext _context;
        private readonly INotificationService _notificationService;

        public ViewingAppointmentService(
            PhongTroDbContext context,
            INotificationService notificationService)
        {
            _context = context;
            _notificationService = notificationService;
        }

        public async Task<ViewingAppointmentDto> CreateAsync(long tenantId, CreateViewingAppointmentDto dto)
        {
            var scheduledAtUtc = NormalizeUtc(dto.ScheduledAt);
            if (!IsValidSlot(scheduledAtUtc, dto.TimezoneOffsetMinutes))
            {
                throw new InvalidOperationException("Vui lòng chọn khung giờ hợp lệ, mỗi 30 phút từ 08:00 đến 20:00.");
            }

            var listing = await _context.Listings
                .Include(x => x.Status)
                .Include(x => x.Landlord)
                .FirstOrDefaultAsync(x => x.ListingId == dto.ListingId);

            if (listing == null)
            {
                throw new InvalidOperationException("Không tìm thấy tin đăng.");
            }

            if (!string.Equals(listing.Status.StatusName, ActiveListingStatus, StringComparison.OrdinalIgnoreCase))
            {
                throw new InvalidOperationException("Tin đăng này hiện chưa thể đặt lịch xem.");
            }

            if (listing.LandlordId == tenantId)
            {
                throw new InvalidOperationException("Bạn không thể đặt lịch xem chính tin đăng của mình.");
            }

            var hasPending = await _context.ViewingAppointments.AnyAsync(x =>
                x.ListingId == dto.ListingId &&
                x.TenantId == tenantId &&
                (x.Status == StatusPending || x.Status == StatusConfirmed));

            if (hasPending)
            {
                throw new InvalidOperationException("Bạn đã có lịch xem đang chờ xử lý hoặc đã xác nhận cho tin này.");
            }

            if (await HasActiveSlotConflictAsync(dto.ListingId, scheduledAtUtc))
            {
                throw new InvalidOperationException("Khung giờ này đã có lịch xem được giữ chỗ. Vui lòng chọn giờ khác.");
            }

            var appointment = new ViewingAppointment
            {
                ListingId = listing.ListingId,
                TenantId = tenantId,
                LandlordId = listing.LandlordId,
                ScheduledAt = scheduledAtUtc,
                Status = StatusPending,
                TenantNote = Truncate(dto.TenantNote, 500),
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.ViewingAppointments.Add(appointment);
            await _context.SaveChangesAsync();

            await _notificationService.CreateAndSendAsync(
                listing.LandlordId,
                "Có lịch hẹn xem phòng mới",
                $"Người thuê muốn xem phòng \"{listing.Title}\" vào {appointment.ScheduledAt.ToLocalTime():dd/MM/yyyy HH:mm}.",
                "appointment_requested",
                appointment.AppointmentId,
                "viewing_appointment");

            await _notificationService.CreateAndSendAsync(
                tenantId,
                "Đã gửi yêu cầu xem phòng",
                $"Yêu cầu xem \"{listing.Title}\" lúc {appointment.ScheduledAt.ToLocalTime():dd/MM/yyyy HH:mm} đang chờ chủ trọ xác nhận.",
                "appointment_request_sent",
                appointment.AppointmentId,
                "viewing_appointment");

            return await BuildDtoAsync(appointment.AppointmentId, tenantId)
                ?? throw new InvalidOperationException("Không thể tạo lịch hẹn.");
        }

        public async Task<List<ViewingAppointmentSlotDto>> GetAvailableSlotsAsync(
            long listingId,
            DateOnly date,
            int timezoneOffsetMinutes)
        {
            var listingExists = await _context.Listings.AnyAsync(x => x.ListingId == listingId);
            if (!listingExists)
            {
                throw new InvalidOperationException("Khong tim thay tin dang.");
            }

            var offset = TimeSpan.FromMinutes(timezoneOffsetMinutes);
            var localDayStart = date.ToDateTime(TimeOnly.MinValue);
            var utcDayStart = localDayStart - offset;
            var utcDayEnd = utcDayStart.AddDays(1);

            var reservedAppointments = await _context.ViewingAppointments
                .Where(x =>
                    x.ListingId == listingId &&
                    (x.Status == StatusPending || x.Status == StatusConfirmed) &&
                    x.ScheduledAt >= utcDayStart.AddMinutes(-SlotConflictWindowMinutes) &&
                    x.ScheduledAt < utcDayEnd.AddMinutes(SlotConflictWindowMinutes))
                .Select(x => x.ScheduledAt)
                .ToListAsync();

            var now = DateTime.UtcNow;
            var slots = new List<ViewingAppointmentSlotDto>();
            for (var hour = SlotStartHour; hour <= SlotEndHour; hour++)
            {
                for (var minute = 0; minute < 60; minute += SlotIntervalMinutes)
                {
                    if (hour == SlotEndHour && minute > 0)
                    {
                        continue;
                    }

                    var localSlot = localDayStart.AddHours(hour).AddMinutes(minute);
                    var utcSlot = DateTime.SpecifyKind(localSlot - offset, DateTimeKind.Utc);
                    var hasConflict = reservedAppointments.Any(x =>
                        Math.Abs((NormalizeUtc(x) - utcSlot).TotalMinutes) < SlotConflictWindowMinutes);

                    slots.Add(new ViewingAppointmentSlotDto
                    {
                        ScheduledAt = utcSlot,
                        Label = localSlot.ToString("HH:mm"),
                        IsAvailable = utcSlot > now && !hasConflict
                    });
                }
            }

            return slots;
        }

        public async Task<List<ViewingAppointmentDto>> GetMyAppointmentsAsync(long userId, string? role, string? status)
        {
            var query = BaseQuery().Where(x => x.TenantId == userId || x.LandlordId == userId);

            if (string.Equals(role, "tenant", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(x => x.TenantId == userId);
            }
            else if (string.Equals(role, "landlord", StringComparison.OrdinalIgnoreCase))
            {
                query = query.Where(x => x.LandlordId == userId);
            }

            if (!string.IsNullOrWhiteSpace(status))
            {
                var normalized = status.Trim().ToLowerInvariant();
                query = query.Where(x => x.Status == normalized);
            }

            var items = await query
                .OrderBy(x => x.Status == StatusPending ? 0 : 1)
                .ThenBy(x => x.ScheduledAt)
                .Take(200)
                .ToListAsync();

            return items.Select(x => MapToDto(x, userId)).ToList();
        }

        public async Task<ViewingAppointmentDto> ConfirmAsync(long appointmentId, long landlordId, string? note)
        {
            var appointment = await BaseQuery().FirstOrDefaultAsync(x => x.AppointmentId == appointmentId)
                ?? throw new InvalidOperationException("Không tìm thấy lịch hẹn.");

            if (appointment.LandlordId != landlordId)
            {
                throw new UnauthorizedAccessException("Bạn không có quyền xác nhận lịch hẹn này.");
            }

            if (appointment.Status != StatusPending)
            {
                throw new InvalidOperationException("Chỉ lịch hẹn đang chờ mới có thể xác nhận.");
            }

            if (await HasActiveSlotConflictAsync(
                    appointment.ListingId,
                    appointment.ScheduledAt,
                    appointment.AppointmentId))
            {
                throw new InvalidOperationException("Khung giờ này đã có lịch xem khác đang được giữ. Vui lòng từ chối lịch này hoặc hẹn lại với khách.");
            }

            appointment.Status = StatusConfirmed;
            appointment.LandlordNote = Truncate(note, 500);
            appointment.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAndSendAsync(
                appointment.TenantId,
                "Lịch xem phòng đã được xác nhận",
                $"Chủ trọ đã xác nhận lịch xem \"{appointment.Listing.Title}\" vào {appointment.ScheduledAt.ToLocalTime():dd/MM/yyyy HH:mm}.",
                "appointment_confirmed",
                appointment.AppointmentId,
                "viewing_appointment");

            return MapToDto(appointment, landlordId);
        }

        public async Task<ViewingAppointmentDto> DeclineAsync(long appointmentId, long landlordId, string? note)
        {
            var appointment = await BaseQuery().FirstOrDefaultAsync(x => x.AppointmentId == appointmentId)
                ?? throw new InvalidOperationException("Không tìm thấy lịch hẹn.");

            if (appointment.LandlordId != landlordId)
            {
                throw new UnauthorizedAccessException("Bạn không có quyền từ chối lịch hẹn này.");
            }

            if (appointment.Status != StatusPending)
            {
                throw new InvalidOperationException("Chỉ lịch hẹn đang chờ mới có thể từ chối.");
            }

            appointment.Status = StatusDeclined;
            appointment.LandlordNote = Truncate(note, 500);
            appointment.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAndSendAsync(
                appointment.TenantId,
                "Lịch xem phòng bị từ chối",
                $"Chủ trọ chưa thể nhận lịch xem \"{appointment.Listing.Title}\" vào thời gian bạn chọn.",
                "appointment_declined",
                appointment.AppointmentId,
                "viewing_appointment");

            return MapToDto(appointment, landlordId);
        }

        public async Task<ViewingAppointmentDto> CancelAsync(long appointmentId, long userId, string? note)
        {
            var appointment = await BaseQuery().FirstOrDefaultAsync(x => x.AppointmentId == appointmentId)
                ?? throw new InvalidOperationException("Không tìm thấy lịch hẹn.");

            if (appointment.TenantId != userId && appointment.LandlordId != userId)
            {
                throw new UnauthorizedAccessException("Bạn không có quyền hủy lịch hẹn này.");
            }

            if (appointment.Status != StatusPending && appointment.Status != StatusConfirmed)
            {
                throw new InvalidOperationException("Lịch hẹn này không thể hủy.");
            }

            appointment.Status = StatusCancelled;
            if (appointment.LandlordId == userId)
            {
                appointment.LandlordNote = Truncate(note, 500);
            }
            else
            {
                appointment.TenantNote = Truncate(note, 500);
            }

            appointment.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            var targetUserId = appointment.LandlordId == userId
                ? appointment.TenantId
                : appointment.LandlordId;

            await _notificationService.CreateAndSendAsync(
                targetUserId,
                "Lịch xem phòng đã bị hủy",
                $"Lịch xem \"{appointment.Listing.Title}\" vào {appointment.ScheduledAt.ToLocalTime():dd/MM/yyyy HH:mm} đã bị hủy.",
                "appointment_cancelled",
                appointment.AppointmentId,
                "viewing_appointment");

            return MapToDto(appointment, userId);
        }

        private IQueryable<ViewingAppointment> BaseQuery()
        {
            return _context.ViewingAppointments
                .Include(x => x.Listing)
                .Include(x => x.Tenant)
                .Include(x => x.Landlord);
        }

        private async Task<ViewingAppointmentDto?> BuildDtoAsync(long appointmentId, long currentUserId)
        {
            var appointment = await BaseQuery()
                .FirstOrDefaultAsync(x => x.AppointmentId == appointmentId);

            return appointment == null ? null : MapToDto(appointment, currentUserId);
        }

        private static ViewingAppointmentDto MapToDto(ViewingAppointment appointment, long currentUserId)
        {
            var isLandlord = appointment.LandlordId == currentUserId;
            var isTenant = appointment.TenantId == currentUserId;
            var isPending = appointment.Status == StatusPending;
            var isConfirmed = appointment.Status == StatusConfirmed;

            return new ViewingAppointmentDto
            {
                AppointmentId = appointment.AppointmentId,
                ListingId = appointment.ListingId,
                ListingTitle = appointment.Listing.Title,
                ListingImage = appointment.Listing.Image0,
                ListingAddress = appointment.Listing.StreetAddress,
                TenantId = appointment.TenantId,
                TenantName = appointment.Tenant.FullName,
                TenantPhone = appointment.Tenant.Phone,
                LandlordId = appointment.LandlordId,
                LandlordName = appointment.Landlord.FullName,
                LandlordPhone = appointment.Landlord.Phone,
                ScheduledAt = appointment.ScheduledAt,
                Status = appointment.Status,
                TenantNote = appointment.TenantNote,
                LandlordNote = appointment.LandlordNote,
                CreatedAt = appointment.CreatedAt,
                UpdatedAt = appointment.UpdatedAt,
                CanConfirm = isLandlord && isPending,
                CanDecline = isLandlord && isPending,
                CanCancel = (isTenant || isLandlord) && (isPending || isConfirmed)
            };
        }

        private async Task<bool> HasActiveSlotConflictAsync(
            long listingId,
            DateTime scheduledAtUtc,
            long? exceptAppointmentId = null)
        {
            scheduledAtUtc = NormalizeUtc(scheduledAtUtc);
            var from = scheduledAtUtc.AddMinutes(-SlotConflictWindowMinutes);
            var to = scheduledAtUtc.AddMinutes(SlotConflictWindowMinutes);

            return await _context.ViewingAppointments.AnyAsync(x =>
                x.ListingId == listingId &&
                (x.Status == StatusPending || x.Status == StatusConfirmed) &&
                (!exceptAppointmentId.HasValue || x.AppointmentId != exceptAppointmentId.Value) &&
                x.ScheduledAt > from &&
                x.ScheduledAt < to);
        }

        private static bool IsValidSlot(DateTime scheduledAtUtc, int timezoneOffsetMinutes)
        {
            var local = scheduledAtUtc.AddMinutes(timezoneOffsetMinutes);
            if (local.Hour < SlotStartHour || local.Hour > SlotEndHour)
            {
                return false;
            }

            if (local.Hour == SlotEndHour && local.Minute != 0)
            {
                return false;
            }

            return local.Second == 0 &&
                   local.Millisecond == 0 &&
                   local.Minute % SlotIntervalMinutes == 0;
        }

        private static DateTime NormalizeUtc(DateTime value)
        {
            return value.Kind == DateTimeKind.Utc
                ? value
                : value.ToUniversalTime();
        }

        private static string? Truncate(string? value, int maxLength)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return null;
            }

            var trimmed = value.Trim();
            return trimmed.Length <= maxLength ? trimmed : trimmed[..maxLength];
        }
    }
}
