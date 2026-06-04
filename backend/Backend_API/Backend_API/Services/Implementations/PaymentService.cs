using Backend_API.Models.DTOs.Payment;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace Backend_API.Services.Implementations
{
    public class PaymentService : IPaymentService
    {
        private readonly PhongTroDbContext _context;
        private readonly INotificationService _notificationService;
        private readonly IPayOsService _payOsService;

        private const string STATUS_PENDING = "pending";
        private const string STATUS_SUCCESS = "success";
        private const string STATUS_FAILED = "failed";
        private const string METHOD_MOMO = "momo";
        private const string METHOD_PAYOS = "payos";

        public PaymentService(
            PhongTroDbContext context,
            INotificationService notificationService,
            IPayOsService payOsService)
        {
            _context = context;
            _notificationService = notificationService;
            _payOsService = payOsService;
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
                ?? throw new Exception("Khong tim thay tin dang.");

            if (listing.LandlordId != landlordId)
            {
                throw new Exception("Ban khong co quyen mua goi cho tin dang nay.");
            }

            var package = await _context.PostPackages
                .FirstOrDefaultAsync(p => p.PackageId == packageId && p.IsActive)
                ?? throw new Exception("Goi dang khong ton tai hoac da ngung hoat dong.");

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
                Note = $"Mua goi {package.PackageName} (PackageId:{packageId}) cho tin #{listingId}",
                StatusId = pendingStatusId,
                CreatedAt = nowUtc,
                UpdatedAt = nowUtc
            };

            await _context.Invoices.AddAsync(invoice);
            await _context.SaveChangesAsync();

            var payOsMethodId = await GetPaymentMethodIdAsync(METHOD_PAYOS);
            var pendingPayment = new Payment
            {
                InvoiceId = invoice.InvoiceId,
                MethodId = payOsMethodId,
                StatusId = pendingStatusId,
                Amount = package.Price,
                TransactionRef = invoice.InvoiceId.ToString(),
                GatewayResponse = null,
                PaidAt = null,
                CreatedAt = nowUtc
            };

            await _context.Payments.AddAsync(pendingPayment);
            await _context.SaveChangesAsync();

            var payOsResult = await _payOsService.CreatePaymentLinkAsync(invoice, package);
            pendingPayment.GatewayResponse = JsonSerializer.Serialize(payOsResult.RawResponse);
            await _context.SaveChangesAsync();

            return MapInvoice(invoice, pendingPayment);
        }

        public async Task ProcessPaymentCallbackAsync(string transactionRef, string gateway)
        {
            if (string.IsNullOrWhiteSpace(transactionRef))
            {
                throw new Exception("transactionRef khong hop le.");
            }

            var payment = await _context.Payments
                .Include(p => p.Invoice)
                .FirstOrDefaultAsync(p =>
                    p.TransactionRef == transactionRef ||
                    p.Invoice.InvoiceCode == transactionRef)
                ?? throw new Exception("Khong tim thay giao dich thanh toan.");

            await MarkPaymentSuccessAsync(payment, gateway);
        }

        public async Task ProcessPayOsWebhookAsync(PayOsWebhookDto webhook)
        {
            if (!_payOsService.VerifyWebhookData(webhook.Data, webhook.Signature))
            {
                throw new Exception("PayOS webhook signature khong hop le.");
            }

            var orderCode = ReadLong(webhook.Data, "orderCode");
            if (orderCode <= 0)
            {
                throw new Exception("PayOS webhook thieu orderCode.");
            }

            var payment = await _context.Payments
                .Include(p => p.Invoice)
                .FirstOrDefaultAsync(p => p.InvoiceId == orderCode)
                ?? throw new Exception("Khong tim thay giao dich PayOS.");

            payment.GatewayResponse = JsonSerializer.Serialize(webhook);

            var dataCode = ReadString(webhook.Data, "code");
            if (webhook.Success && dataCode == "00")
            {
                await _context.SaveChangesAsync();
                await MarkPaymentSuccessAsync(payment, METHOD_PAYOS);
                return;
            }

            var failedStatusId = await GetPaymentStatusIdAsync(STATUS_FAILED);
            payment.StatusId = failedStatusId;
            payment.Invoice.StatusId = failedStatusId;
            payment.Invoice.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        public async Task<InvoiceResponseDto> SyncPayOsInvoiceAsync(long landlordId, string invoiceCode)
        {
            if (string.IsNullOrWhiteSpace(invoiceCode))
            {
                throw new Exception("invoiceCode khong hop le.");
            }

            var invoice = await _context.Invoices
                .Include(i => i.Status)
                .Include(i => i.Payments)
                    .ThenInclude(p => p.Method)
                .Include(i => i.Payments)
                    .ThenInclude(p => p.Status)
                .FirstOrDefaultAsync(i =>
                    i.LandlordId == landlordId &&
                    i.InvoiceCode == invoiceCode)
                ?? throw new Exception("Khong tim thay hoa don.");

            var latestPayment = invoice.Payments
                .OrderByDescending(p => p.CreatedAt)
                .FirstOrDefault(p =>
                    p.Method != null &&
                    p.Method.MethodName.ToLower() == METHOD_PAYOS)
                ?? invoice.Payments.OrderByDescending(p => p.CreatedAt).FirstOrDefault()
                ?? throw new Exception("Khong tim thay giao dich thanh toan.");

            var successStatusId = await GetPaymentStatusIdAsync(STATUS_SUCCESS);
            if (invoice.StatusId == successStatusId || latestPayment.StatusId == successStatusId)
            {
                return await GetInvoiceResponseAsync(landlordId, invoiceCode);
            }

            var payOsInfo = await _payOsService.GetPaymentLinkInfoAsync(invoice.InvoiceId);
            var normalizedStatus = payOsInfo.Status.Trim().ToUpperInvariant();

            if (normalizedStatus == "PAID")
            {
                latestPayment.GatewayResponse ??= JsonSerializer.Serialize(payOsInfo.RawResponse);
                await _context.SaveChangesAsync();
                await MarkPaymentSuccessAsync(latestPayment, METHOD_PAYOS);
            }
            else if (normalizedStatus is "CANCELLED" or "EXPIRED")
            {
                var failedStatusId = await GetPaymentStatusIdAsync(STATUS_FAILED);
                latestPayment.StatusId = failedStatusId;
                invoice.StatusId = failedStatusId;
                invoice.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();
            }

            return await GetInvoiceResponseAsync(landlordId, invoiceCode);
        }

        public async Task<List<InvoiceResponseDto>> GetMyInvoicesAsync(long landlordId)
        {
            var invoices = await _context.Invoices
                .Include(i => i.Status)
                .Include(i => i.Payments)
                    .ThenInclude(p => p.Method)
                .Include(i => i.Payments)
                    .ThenInclude(p => p.Status)
                .Where(i => i.LandlordId == landlordId)
                .OrderByDescending(i => i.CreatedAt)
                .ToListAsync();

            return invoices.Select(MapInvoice).ToList();
        }

        private async Task<InvoiceResponseDto> GetInvoiceResponseAsync(long landlordId, string invoiceCode)
        {
            var invoice = await _context.Invoices
                .Include(i => i.Status)
                .Include(i => i.Payments)
                    .ThenInclude(p => p.Method)
                .Include(i => i.Payments)
                    .ThenInclude(p => p.Status)
                .FirstOrDefaultAsync(i =>
                    i.LandlordId == landlordId &&
                    i.InvoiceCode == invoiceCode)
                ?? throw new Exception("Khong tim thay hoa don.");

            return MapInvoice(invoice);
        }

        private async Task MarkPaymentSuccessAsync(Payment payment, string gateway)
        {
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

            payment.Invoice.StatusId = successStatusId;
            payment.Invoice.UpdatedAt = nowUtc;

            var listing = await _context.Listings
                .FirstOrDefaultAsync(l => l.ListingId == payment.Invoice.ListingId)
                ?? throw new Exception("Khong tim thay tin dang cua hoa don.");

            var package = await ResolvePurchasedPackageAsync(payment.Invoice.InvoiceId)
                ?? throw new Exception("Khong tim thay goi dang da chon cho hoa don.");

            var hasActivePackage = await _context.ListingPostPackages
                .AnyAsync(lpp =>
                    lpp.PaymentId == payment.PaymentId &&
                    lpp.PackageId == package.PackageId &&
                    lpp.IsActive == true &&
                    lpp.EndDate > nowUtc);

            if (!hasActivePackage)
            {
                await _context.ListingPostPackages.AddAsync(new ListingPostPackage
                {
                    ListingId = listing.ListingId,
                    PackageId = package.PackageId,
                    PaymentId = payment.PaymentId,
                    StartDate = nowUtc,
                    EndDate = nowUtc.AddDays(package.DurationDays),
                    IsActive = true,
                    CreatedAt = nowUtc
                });
            }

            if (package.IsHighlighted)
            {
                listing.IsFeatured = true;
            }

            listing.UpdatedAt = nowUtc;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAndSendAsync(
                payment.Invoice.LandlordId,
                "Thanh toan thanh cong",
                $"Hoa don {payment.Invoice.InvoiceCode} da thanh toan thanh cong qua {gateway.ToUpperInvariant()}.",
                "payment_success",
                payment.Invoice.InvoiceId,
                "invoice");
        }

        private async Task<int> GetPaymentStatusIdAsync(string statusName)
        {
            var status = await _context.PaymentStatuses
                .FirstOrDefaultAsync(s => s.StatusName == statusName)
                ?? throw new Exception($"Khong tim thay PaymentStatus = '{statusName}'.");

            return status.StatusId;
        }

        private async Task<int> GetPaymentMethodIdAsync(string gateway)
        {
            if (string.IsNullOrWhiteSpace(gateway))
            {
                throw new Exception("gateway khong hop le.");
            }

            var normalized = gateway.Trim().ToLowerInvariant();
            var method = await _context.PaymentMethods
                .FirstOrDefaultAsync(m => m.IsActive == true && m.MethodName.ToLower() == normalized);

            if (method != null) return method.MethodId;

            if (normalized == METHOD_PAYOS)
            {
                method = new PaymentMethod
                {
                    MethodName = METHOD_PAYOS,
                    IsActive = true
                };
                await _context.PaymentMethods.AddAsync(method);
                await _context.SaveChangesAsync();
                return method.MethodId;
            }

            method = await _context.PaymentMethods
                .FirstOrDefaultAsync(m => m.IsActive == true)
                ?? throw new Exception("Khong co phuong thuc thanh toan kha dung.");

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

            var invoice = await _context.Invoices.FirstOrDefaultAsync(i => i.InvoiceId == invoiceId);
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

            return int.TryParse(digits, out var packageId)
                ? await _context.PostPackages.FirstOrDefaultAsync(p => p.PackageId == packageId)
                : null;
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
            var latestPayment = invoice.Payments
                .OrderByDescending(p => p.CreatedAt)
                .FirstOrDefault();

            return MapInvoice(invoice, latestPayment);
        }

        private static InvoiceResponseDto MapInvoice(Invoice invoice, Payment? latestPayment)
        {
            var (paymentUrl, qrCode) = ExtractPayOsPaymentFields(latestPayment?.GatewayResponse);

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
                PaymentStatus = latestPayment?.Status?.StatusName ?? invoice.Status?.StatusName,
                PaymentMethod = latestPayment?.Method?.MethodName,
                PaymentUrl = paymentUrl,
                PaymentQrCode = qrCode,
                CreatedAt = invoice.CreatedAt,
                UpdatedAt = invoice.UpdatedAt
            };
        }

        private static (string? PaymentUrl, string? QrCode) ExtractPayOsPaymentFields(string? gatewayResponse)
        {
            if (string.IsNullOrWhiteSpace(gatewayResponse))
            {
                return (null, null);
            }

            try
            {
                using var document = JsonDocument.Parse(gatewayResponse);
                var root = document.RootElement;
                if (!root.TryGetProperty("data", out var data))
                {
                    return (null, null);
                }

                var checkoutUrl = data.TryGetProperty("checkoutUrl", out var checkout)
                    ? checkout.GetString()
                    : null;
                var qrCode = data.TryGetProperty("qrCode", out var qr)
                    ? qr.GetString()
                    : null;
                return (checkoutUrl, qrCode);
            }
            catch
            {
                return (null, null);
            }
        }

        private static long ReadLong(JsonElement data, string propertyName)
        {
            if (!data.TryGetProperty(propertyName, out var value))
            {
                return 0;
            }

            if (value.ValueKind == JsonValueKind.Number && value.TryGetInt64(out var longValue))
            {
                return longValue;
            }

            return long.TryParse(value.ToString(), out var parsed) ? parsed : 0;
        }

        private static string ReadString(JsonElement data, string propertyName)
        {
            return data.TryGetProperty(propertyName, out var value)
                ? value.ToString()
                : string.Empty;
        }
    }
}
