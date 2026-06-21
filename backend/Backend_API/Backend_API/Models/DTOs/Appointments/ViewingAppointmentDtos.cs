namespace Backend_API.Models.DTOs.Appointments
{
    public class ViewingAppointmentDto
    {
        public long AppointmentId { get; set; }
        public long ListingId { get; set; }
        public string ListingTitle { get; set; } = string.Empty;
        public string? ListingImage { get; set; }
        public string? ListingAddress { get; set; }
        public long TenantId { get; set; }
        public string TenantName { get; set; } = string.Empty;
        public string? TenantPhone { get; set; }
        public long LandlordId { get; set; }
        public string LandlordName { get; set; } = string.Empty;
        public string? LandlordPhone { get; set; }
        public DateTime ScheduledAt { get; set; }
        public string Status { get; set; } = string.Empty;
        public string? TenantNote { get; set; }
        public string? LandlordNote { get; set; }
        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
        public bool CanConfirm { get; set; }
        public bool CanDecline { get; set; }
        public bool CanCancel { get; set; }
    }

    public class CreateViewingAppointmentDto
    {
        public long ListingId { get; set; }
        public DateTime ScheduledAt { get; set; }
        public int TimezoneOffsetMinutes { get; set; } = 420;
        public string? TenantNote { get; set; }
    }

    public class UpdateViewingAppointmentStatusDto
    {
        public string? Note { get; set; }
    }

    public class ViewingAppointmentSlotDto
    {
        public DateTime ScheduledAt { get; set; }
        public string Label { get; set; } = string.Empty;
        public bool IsAvailable { get; set; }
    }
}
