using System.ComponentModel.DataAnnotations;

namespace Backend_API.Models.DTOs.Payment
{
    public class SimulatePaymentDto
    {
        [Required]
        public string InvoiceCode { get; set; } = null!;
    }
}
