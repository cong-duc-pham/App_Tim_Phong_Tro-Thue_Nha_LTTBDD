using Backend_API.Models.DTOs.Appointments;

namespace Backend_API.Services.Interfaces
{
    public interface IViewingAppointmentService
    {
        Task<ViewingAppointmentDto> CreateAsync(long tenantId, CreateViewingAppointmentDto dto);
        Task<List<ViewingAppointmentSlotDto>> GetAvailableSlotsAsync(long listingId, DateOnly date, int timezoneOffsetMinutes);
        Task<List<ViewingAppointmentDto>> GetMyAppointmentsAsync(long userId, string? role, string? status);
        Task<ViewingAppointmentDto> ConfirmAsync(long appointmentId, long landlordId, string? note);
        Task<ViewingAppointmentDto> DeclineAsync(long appointmentId, long landlordId, string? note);
        Task<ViewingAppointmentDto> CancelAsync(long appointmentId, long userId, string? note);
    }
}
