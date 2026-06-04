namespace Backend_API.Models.DTOs.Payment
{
    public class InvoiceResponseDto
    {
        public long InvoiceId { get; set; }
        public long LandlordId { get; set; }
        public long? ListingId { get; set; }
        public string InvoiceCode { get; set; } = null!;
        public string InvoiceType { get; set; } = null!;
        public decimal TotalAmount { get; set; }
        public DateOnly DueDate { get; set; }
        public string? Note { get; set; }
        public int StatusId { get; set; }
        public string? PaymentStatus { get; set; }
        public string? PaymentMethod { get; set; }
        public string? PaymentUrl { get; set; }
        public string? PaymentQrCode { get; set; }
        public DateTime? CreatedAt { get; set; }
        public DateTime? UpdatedAt { get; set; }
    }
}
