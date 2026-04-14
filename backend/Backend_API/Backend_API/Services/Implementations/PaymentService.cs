using Backend_API.Models.DTOs.Payment;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class PaymentService : IPaymentService
    {
        private readonly PhongTroDbContext _context;
        private readonly INotificationService _notificationService;

        private const string STATUS_PENDING = "pending";
        private const string STATUS_SUCCESS = "success";
        private const string METHOD_MOMO = "momo";

        public PaymentService(PhongTroDbContext context, INotificationService notificationService)
        {
            _context = context;
            _notificationService = notificationService;
        }

        public async Task<List<PackageListDto>> GetPackagesAsync()
        {
            var packages = await _context.PostPackages
                .Where(p => p.IsActive)
                .OrderByDescending(p => p.Priority)
                .ThenBy(p => p.Price)
                .ToListAsync();

            return packages.Select(p => new PackageListDto
            {
                PackageId = p.PackageId,
                PackageName = p.PackageName,
                PackageType = p.PackageType,
                DurationDays = p.DurationDays,
                Price = p.Price,
                Priority = p.Priority,
                MaxImages = p.MaxImages,
                MaxVideos = p.MaxVideos,
                AllowBanner = p.AllowBanner,
                BadgeType = p.BadgeType,
                HasAnalytics = p.HasAnalytics,
                IsHighlighted = p.IsHighlighted,
                Description = p.Description,
                IsActive = p.IsActive
            }).ToList();
        }

        public async Task<InvoiceResponseDto> CreateInvoiceAsync(long landlordId, long listingId, int packageId)
        {
            var listing = await _context.Listings
                .FirstOrDefaultAsync(l => l.ListingId == listingId)
                ?? throw new Exception("Không tìm thấy tin đăng.");

            if (listing.LandlordId != landlordId)
            {
                throw new Exception("Bạn không có quyền mua gói cho tin đăng này.");
            }

            var package = await _context.PostPackages
                .FirstOrDefaultAsync(p => p.PackageId == packageId && p.IsActive)
                ?? throw new Exception("Gói đăng không tồn tại hoặc đã ngừng hoạt động.");

            var pendingStatusId = await GetPaymentStatusIdAsync(STATUS_PENDING);
            var invoiceCode = await GenerateInvoiceCodeAsync();
            var nowUtc = DateTime.UtcNow;

            var invoice = new Invoice
            {
                LandlordId = landlordId,
                ListingId = listingId,
                InvoiceCode = invoiceCode,
                InvoiceType = "post_package",
                TotalAmount = package.Price,
                DueDate = DateOnly.FromDateTime(nowUtc.AddDays(1)),
                Note = $"Mua gói {package.PackageName} (PackageId:{packageId}) cho tin #{listingId}",
                StatusId = pendingStatusId,
                CreatedAt = nowUtc,
                UpdatedAt = nowUtc
            };

            await _context.Invoices.AddAsync(invoice);
            await _context.SaveChangesAsync(); // lấy invoice_id

            var pendingMethodId = await GetPaymentMethodIdAsync(METHOD_MOMO);
            var pendingPayment = new Payment
            {
                InvoiceId = invoice.InvoiceId,
                MethodId = pendingMethodId,
                StatusId = pendingStatusId,
                Amount = package.Price,
                TransactionRef = invoice.InvoiceCode,
                GatewayResponse = null,
                PaidAt = null,
                CreatedAt = nowUtc
            };

            await _context.Payments.AddAsync(pendingPayment);
            await _context.SaveChangesAsync();

            return MapInvoice(invoice);
        }

        public async Task ProcessPaymentCallbackAsync(string transactionRef, string gateway)
        {
            if (string.IsNullOrWhiteSpace(transactionRef))
            {
                throw new Exception("transactionRef không hợp lệ.");
            }

            var payment = await _context.Payments
                .Include(p => p.Invoice)
                .FirstOrDefaultAsync(p => p.TransactionRef == transactionRef)
                ?? throw new Exception("Không tìm thấy giao dịch thanh toán.");

            var successStatusId = await GetPaymentStatusIdAsync(STATUS_SUCCESS);
            var methodId = await GetPaymentMethodIdAsync(gateway);
            var nowUtc = DateTime.UtcNow;

            if (payment.StatusId == successStatusId)
            {
                return;
            }

            payment.StatusId = successStatusId;
            payment.MethodId = methodId;
            payment.PaidAt = nowUtc;
            payment.GatewayResponse = gateway;

            payment.Invoice.StatusId = successStatusId;
            payment.Invoice.UpdatedAt = nowUtc;

            var listing = await _context.Listings
                .FirstOrDefaultAsync(l => l.ListingId == payment.Invoice.ListingId)
                ?? throw new Exception("Không tìm thấy tin đăng của hóa đơn.");

            var package = await ResolvePurchasedPackageAsync(payment.Invoice.InvoiceId)
                ?? throw new Exception("Không tìm thấy gói đăng đã chọn cho hóa đơn.");

            var startDate = nowUtc;
            var endDate = nowUtc.AddDays(package.DurationDays);

            var hasActivePackage = await _context.ListingPostPackages
                .AnyAsync(lpp =>
                    lpp.PaymentId == payment.PaymentId &&
                    lpp.PackageId == package.PackageId &&
                    lpp.IsActive == true &&
                    lpp.EndDate > nowUtc);

            if (!hasActivePackage)
            {
                var listingPostPackage = new ListingPostPackage
                {
                    ListingId = listing.ListingId,
                    PackageId = package.PackageId,
                    PaymentId = payment.PaymentId,
                    StartDate = startDate,
                    EndDate = endDate,
                    IsActive = true,
                    CreatedAt = nowUtc
                };

                await _context.ListingPostPackages.AddAsync(listingPostPackage);
            }

            if (package.IsHighlighted)
            {
                listing.IsFeatured = true;
            }

            listing.UpdatedAt = nowUtc;

            await _context.SaveChangesAsync();

            await _notificationService.CreateAndSendAsync(
                payment.Invoice.LandlordId,
                "Thanh toán thành công",
                $"Thanh toán hóa đơn {payment.Invoice.InvoiceCode} thành công qua {gateway.ToUpperInvariant()}.",
                "payment_success",
                payment.Invoice.InvoiceId,
                "invoice");
        }

        public async Task<List<InvoiceResponseDto>> GetMyInvoicesAsync(long landlordId)
        {
            var invoices = await _context.Invoices
                .Where(i => i.LandlordId == landlordId)
                .OrderByDescending(i => i.CreatedAt)
                .ToListAsync();

            return invoices.Select(MapInvoice).ToList();
        }

        private async Task<int> GetPaymentStatusIdAsync(string statusName)
        {
            var status = await _context.PaymentStatuses
                .FirstOrDefaultAsync(s => s.StatusName == statusName)
                ?? throw new Exception($"Không tìm thấy PaymentStatus = '{statusName}'.");

            return status.StatusId;
        }

        private async Task<int> GetPaymentMethodIdAsync(string gateway)
        {
            if (string.IsNullOrWhiteSpace(gateway))
            {
                throw new Exception("gateway không hợp lệ.");
            }

            var normalized = gateway.Trim().ToLowerInvariant();
            var method = await _context.PaymentMethods
                .FirstOrDefaultAsync(m => m.IsActive == true && m.MethodName.ToLower() == normalized);

            if (method != null) return method.MethodId;

            method = await _context.PaymentMethods
                .FirstOrDefaultAsync(m => m.IsActive == true)
                ?? throw new Exception("Không có phương thức thanh toán khả dụng.");

            return method.MethodId;
        }

        private async Task<PostPackage?> ResolvePurchasedPackageAsync(long invoiceId)
        {
            var linkedPackageId = await _context.ListingPostPackages
                .Where(lpp => lpp.Payment != null && lpp.Payment.InvoiceId == invoiceId)
                .OrderByDescending(lpp => lpp.LppId)
                .Select(lpp => (int?)lpp.PackageId)
                .FirstOrDefaultAsync();

            if (linkedPackageId.HasValue)
            {
                return await _context.PostPackages.FirstOrDefaultAsync(p => p.PackageId == linkedPackageId.Value);
            }

            var invoice = await _context.Invoices
                .FirstOrDefaultAsync(i => i.InvoiceId == invoiceId);

            if (invoice == null || string.IsNullOrWhiteSpace(invoice.Note))
            {
                return null;
            }

            var marker = "PackageId:";
            var index = invoice.Note.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
            if (index < 0)
            {
                return null;
            }

            var start = index + marker.Length;
            var digits = new string(invoice.Note
                .Skip(start)
                .TakeWhile(char.IsDigit)
                .ToArray());

            if (!int.TryParse(digits, out var packageId))
            {
                return null;
            }

            return await _context.PostPackages.FirstOrDefaultAsync(p => p.PackageId == packageId);

        }

        private async Task<string> GenerateInvoiceCodeAsync()
        {
            var datePart = DateTime.UtcNow.ToString("yyyyMMdd");
            var prefix = $"INV-{datePart}-";

            var lastCode = await _context.Invoices
                .Where(i => i.InvoiceCode.StartsWith(prefix))
                .OrderByDescending(i => i.InvoiceCode)
                .Select(i => i.InvoiceCode)
                .FirstOrDefaultAsync();

            var nextNumber = 1;
            if (!string.IsNullOrEmpty(lastCode) && lastCode.Length >= prefix.Length + 4)
            {
                var tail = lastCode.Substring(prefix.Length, 4);
                if (int.TryParse(tail, out var parsed))
                {
                    nextNumber = parsed + 1;
                }
            }

            return $"{prefix}{nextNumber:0000}";
        }

        private static InvoiceResponseDto MapInvoice(Invoice invoice)
        {
            return new InvoiceResponseDto
            {
                InvoiceId = invoice.InvoiceId,
                LandlordId = invoice.LandlordId,
                ListingId = invoice.ListingId,
                InvoiceCode = invoice.InvoiceCode,
                InvoiceType = invoice.InvoiceType,
                TotalAmount = invoice.TotalAmount,
                DueDate = invoice.DueDate,
                Note = invoice.Note,
                StatusId = invoice.StatusId,
                CreatedAt = invoice.CreatedAt,
                UpdatedAt = invoice.UpdatedAt
            };
        }
    }
}
