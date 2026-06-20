using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Backend_API.Helpers;
using Backend_API.Models.Entities;
using Backend_API.Models.ViewModels.Admin;
using Backend_API.Services.Interfaces;
using FirebaseAdmin;
using FirebaseAdmin.Auth;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers.MVC
{
    [Authorize(AuthenticationSchemes = CookieAuthenticationDefaults.AuthenticationScheme)]
    [Route("admin")]
    public class AdminController : Controller
    {
        private const string ListingStatusActive = "active";
        private const string ListingStatusPending = "pending";
        private const string ListingStatusRejected = "rejected";
        private const string ReportStatusPending = "pending";
        private const string ReportStatusResolved = "resolved";
        private const string ReportStatusDismissed = "dismissed";
        private const string PaymentStatusSuccess = "success";
        private const string RoleAdmin = "admin";
        private const string RoleTenant = "tenant";
        private const string RoleLandlord = "landlord";

        private readonly PhongTroDbContext _context;
        private readonly INotificationService _notificationService;
        private readonly IListingRealtimeNotifier _listingRealtimeNotifier;
        private readonly CloudinaryStorageHelper _cloudinaryStorageHelper;

        public AdminController(
            PhongTroDbContext context,
            INotificationService notificationService,
            IListingRealtimeNotifier listingRealtimeNotifier,
            CloudinaryStorageHelper cloudinaryStorageHelper)
        {
            _context = context;
            _notificationService = notificationService;
            _listingRealtimeNotifier = listingRealtimeNotifier;
            _cloudinaryStorageHelper = cloudinaryStorageHelper;
        }

        [HttpGet("")]
        public IActionResult Index()
        {
            return RedirectToAction(nameof(Dashboard));
        }

        [HttpGet("dashboard")]
        public async Task<IActionResult> Dashboard()
        {
            var today = DateTime.UtcNow.Date;
            var startDate = today.AddDays(-29);
            var monthStart = new DateTime(today.Year, today.Month, 1);

            var labels = Enumerable.Range(0, 30)
                .Select(i => startDate.AddDays(i))
                .ToList();

            var newUsersByDate = await _context.Users
                .AsNoTracking()
                .Where(x =>
                    x.CreatedAt != null &&
                    x.CreatedAt >= startDate &&
                    x.CreatedAt < today.AddDays(1))
                .GroupBy(x => DateOnly.FromDateTime(x.CreatedAt!.Value))
                .Select(x => new
                {
                    Date = x.Key,
                    Count = x.Count()
                })
                .ToDictionaryAsync(x => x.Date, x => x.Count);

            var revenueByDate = await _context.Payments
                .Include(x => x.Status)
                .Where(x =>
                    x.Status.StatusName == PaymentStatusSuccess &&
                    x.PaidAt != null &&
                    x.PaidAt >= startDate &&
                    x.PaidAt < today.AddDays(1))
                .GroupBy(x => DateOnly.FromDateTime(x.PaidAt!.Value))
                .Select(x => new
                {
                    Date = x.Key,
                    Revenue = x.Sum(p => p.Amount)
                })
                .ToDictionaryAsync(x => x.Date, x => x.Revenue);

            var model = new AdminDashboardViewModel
            {
                TotalUsers = await _context.Users.CountAsync(),
                TotalFirebaseUsers = await _context.Users.CountAsync(x => x.FirebaseUid != null && x.FirebaseUid != ""),
                TotalActiveListings = await _context.Listings
                    .Include(x => x.Status)
                    .CountAsync(x => x.Status.StatusName == ListingStatusActive),
                RevenueThisMonth = await _context.Payments
                    .Include(x => x.Status)
                    .Where(x => x.Status.StatusName == PaymentStatusSuccess && x.PaidAt != null && x.PaidAt >= monthStart)
                    .SumAsync(x => (decimal?)x.Amount) ?? 0m,
                FcmSentCount = await _context.Notifications.CountAsync(x => x.FcmStatus == "sent"),
                FcmFailedCount = await _context.Notifications.CountAsync(x => x.FcmStatus == "failed"),
                Last30DayLabels = labels.Select(x => x.ToString("dd/MM")).ToList(),
                NewUsers30Days = labels.Select(day =>
                {
                    var key = DateOnly.FromDateTime(day);
                    return newUsersByDate.TryGetValue(key, out var count) ? count : 0;
                }).ToList(),
                Revenue30Days = labels.Select(day =>
                {
                    var key = DateOnly.FromDateTime(day);
                    return revenueByDate.TryGetValue(key, out var revenue) ? revenue : 0m;
                }).ToList()
            };

            ViewData["Title"] = "Dashboard";
            return View(model);
        }

        [HttpGet("users")]
        public async Task<IActionResult> Users()
        {
            await TryAutoSyncFirebaseUsersAsync();
            await SyncUserRolesByListingsAsync();

            var users = await _context.Users
                .Include(x => x.Role)
                .Where(x => x.Role.RoleName.ToLower() != RoleAdmin)
                .OrderByDescending(x => x.UserId)
                .Select(x => new AdminUserItemViewModel
                {
                    UserId = x.UserId,
                    FullName = x.FullName,
                    Email = x.Email,
                    RoleName = x.Role.RoleName,
                    FirebaseUid = x.FirebaseUid,
                    AuthMethod = x.FirebaseUid != null && x.FirebaseUid != "" && x.PasswordHash != null && x.PasswordHash != ""
                        ? "hybrid"
                        : x.FirebaseUid != null && x.FirebaseUid != ""
                            ? "firebase_only"
                            : "password_only",
                    IsActive = x.IsActive == true
                })
                .ToListAsync();

            ViewData["Title"] = "Quản lý Users";
            return View(new AdminUsersViewModel { Users = users });
        }

        [HttpPost("users/sync-firebase")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SyncFirebaseUsers()
        {
            try
            {
                var (createdCount, updatedCount, skippedCount) = await SyncFirebaseUsersToSqlAsync();
                TempData["AdminSuccess"] = $"Đã đồng bộ Firebase: {createdCount} user mới, cập nhật {updatedCount} user, bỏ qua {skippedCount} user.";
            }
            catch (Exception ex)
            {
                var detail = ex.InnerException?.Message ?? ex.Message;
                TempData["AdminError"] = $"Đồng bộ Firebase thất bại: {detail}";
            }

            return RedirectToAction(nameof(Users));
        }

        [HttpPost("users/{id:long}/toggle-active")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ToggleUserActive(long id)
        {
            var user = await _context.Users.FirstOrDefaultAsync(x => x.UserId == id);
            if (user == null)
            {
                return NotFound();
            }

            user.IsActive = !(user.IsActive ?? true);
            user.UpdatedAt = DateTime.UtcNow;

            if (user.IsActive != true)
            {
                var refreshTokens = await _context.SocialAuthProviders
                    .Where(x => x.UserId == user.UserId && x.Provider == "internal_refresh")
                    .ToListAsync();
                foreach (var refreshToken in refreshTokens)
                {
                    refreshToken.TokenExpiresAt = DateTime.UtcNow.AddSeconds(-1);
                    refreshToken.UpdatedAt = DateTime.UtcNow;
                }
            }

            if (!string.IsNullOrWhiteSpace(user.FirebaseUid))
            {
                try
                {
                    await FirebaseAuth.DefaultInstance.UpdateUserAsync(new UserRecordArgs
                    {
                        Uid = user.FirebaseUid,
                        Disabled = user.IsActive != true
                    });
                }
                catch
                {
                    // SQL is the source of truth for API access; Firebase sync is best-effort.
                }
            }

            await _context.SaveChangesAsync();

            return RedirectToAction(nameof(Users));
        }

        [HttpGet("listings")]
        public async Task<IActionResult> Listings()
        {
            var listings = await _context.Listings
                .Include(x => x.Status)
                .Include(x => x.Landlord)
                .Where(x => x.Status.StatusName == ListingStatusPending)
                .OrderByDescending(x => x.CreatedAt)
                .Select(x => new AdminListingItemViewModel
                {
                    ListingId = x.ListingId,
                    Title = x.Title,
                    Price = x.Price,
                    LandlordName = x.Landlord.FullName,
                    LandlordEmail = x.Landlord.Email,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

            ViewData["Title"] = "Duy\u1EC7t tin \u0111\u0103ng";
            return View(new AdminListingsViewModel { Listings = listings });
        }

        [HttpGet("listing-management")]
        public async Task<IActionResult> ListingManagement([FromQuery] string? status, [FromQuery] string? keyword)
        {
            var query = _context.Listings
                .Include(x => x.Status)
                .Include(x => x.Landlord)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status))
            {
                var normalizedStatus = status.Trim().ToLowerInvariant();
                query = query.Where(x => x.Status.StatusName.ToLower() == normalizedStatus);
            }

            if (!string.IsNullOrWhiteSpace(keyword))
            {
                var normalizedKeyword = keyword.Trim().ToLower();
                query = query.Where(x =>
                    x.Title.ToLower().Contains(normalizedKeyword) ||
                    x.StreetAddress.ToLower().Contains(normalizedKeyword) ||
                    (x.Landlord.Email != null && x.Landlord.Email.ToLower().Contains(normalizedKeyword)) ||
                    x.Landlord.FullName.ToLower().Contains(normalizedKeyword));
            }

            var statuses = await _context.ListingStatuses
                .OrderBy(x => x.StatusId)
                .Select(x => x.StatusName)
                .ToListAsync();

            var listings = await query
                .OrderByDescending(x => x.CreatedAt)
                .Take(500)
                .Select(x => new AdminListingItemViewModel
                {
                    ListingId = x.ListingId,
                    Title = x.Title,
                    Price = x.Price,
                    LandlordName = x.Landlord.FullName,
                    LandlordEmail = x.Landlord.Email,
                    StatusName = x.Status.StatusName,
                    Image0 = ToAdminImageUrl(x.Image0),
                    ViewCount = x.ViewCount,
                    SaveCount = x.SaveCount,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

            ViewData["Title"] = "Quản lý tin đăng";
            return View(new AdminListingManagementViewModel
            {
                Status = status,
                Keyword = keyword,
                Statuses = statuses,
                Listings = listings
            });
        }

        [HttpGet("listings/{id:long}")]
        public async Task<IActionResult> ListingDetail(long id, [FromQuery] string? from)
        {
            var listing = await _context.Listings
                .Include(x => x.Status)
                .Include(x => x.Type)
                .Include(x => x.Landlord)
                .Include(x => x.Province)
                .Include(x => x.District)
                .Include(x => x.Ward)
                .Include(x => x.ListingImages)
                .Include(x => x.ListingVideos)
                .Include(x => x.ListingAmenities)
                    .ThenInclude(x => x.Amenity)
                .Include(x => x.ListingPostPackages)
                    .ThenInclude(x => x.Package)
                .Include(x => x.ListingPostPackages)
                    .ThenInclude(x => x.Payment)
                        .ThenInclude(x => x!.Status)
                .FirstOrDefaultAsync(x => x.ListingId == id);

            if (listing == null)
            {
                return NotFound();
            }

            var imageUrls = new[]
                {
                    listing.Image0,
                    listing.Image1,
                    listing.Image2,
                    listing.Image3,
                    listing.Image4,
                    listing.Image5
                }
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(ToAdminImageUrl)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .OfType<string>()
                .ToList();

            imageUrls.AddRange(listing.ListingImages
                .OrderByDescending(x => x.IsCover == true)
                .ThenBy(x => x.SortOrder)
                .Select(x => string.IsNullOrWhiteSpace(x.SecureUrl) ? x.CloudinaryUrl : x.SecureUrl!)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(ToAdminImageUrl)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .OfType<string>());

            var model = new AdminListingDetailViewModel
            {
                IsManagementContext = string.Equals(from, "management", StringComparison.OrdinalIgnoreCase),
                ListingId = listing.ListingId,
                Title = listing.Title,
                Description = listing.Description,
                Price = listing.Price,
                Area = listing.Area,
                Floor = listing.Floor,
                TotalFloors = listing.TotalFloors,
                MaxOccupants = listing.MaxOccupants,
                RoomType = listing.Type.TypeName,
                StatusName = listing.Status.StatusName,
                StreetAddress = listing.StreetAddress,
                WardName = listing.Ward?.WardName,
                DistrictName = listing.District?.DistrictName,
                ProvinceName = listing.Province?.ProvinceName,
                AllowPet = listing.AllowPet,
                IsVerified = listing.IsVerified,
                IsFeatured = listing.IsFeatured,
                IsNew = listing.IsNew,
                ElectricPrice = listing.ElectricPrice,
                WaterPrice = listing.WaterPrice,
                InternetPrice = listing.InternetPrice,
                ParkingPrice = listing.ParkingPrice,
                ViewCount = listing.ViewCount,
                SaveCount = listing.SaveCount,
                AvailableFrom = listing.AvailableFrom,
                ExpiredAt = listing.ExpiredAt,
                CreatedAt = listing.CreatedAt,
                UpdatedAt = listing.UpdatedAt,
                LandlordName = listing.Landlord.FullName,
                LandlordEmail = listing.Landlord.Email,
                LandlordPhone = listing.Landlord.Phone,
                LandlordFirebaseUid = listing.Landlord.FirebaseUid,
                ImageUrls = imageUrls.Distinct().ToList(),
                Videos = listing.ListingVideos
                    .OrderBy(x => x.CreatedAt)
                    .Select(x => new AdminListingVideoViewModel
                    {
                        VideoId = x.VideoId,
                        Url = ToAdminImageUrl(x.CloudinaryUrl) ?? x.CloudinaryUrl,
                        ThumbnailUrl = string.IsNullOrWhiteSpace(x.ThumbnailUrl)
                            ? null
                            : ToAdminImageUrl(x.ThumbnailUrl),
                        DurationSec = x.DurationSec,
                        FileSizeKb = x.FileSizeKb,
                        CreatedAt = x.CreatedAt
                    })
                    .ToList(),
                Amenities = listing.ListingAmenities
                    .Select(x => x.Amenity.Name)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .OrderBy(x => x)
                    .ToList(),
                Packages = listing.ListingPostPackages
                    .OrderByDescending(x => x.IsActive == true)
                    .ThenByDescending(x => x.EndDate)
                    .Select(x => new AdminListingPackageViewModel
                    {
                        PackageName = x.Package.PackageName,
                        PackageType = x.Package.PackageType,
                        Price = x.Package.Price,
                        Priority = x.Package.Priority,
                        MaxImages = x.Package.MaxImages,
                        MaxVideos = x.Package.MaxVideos,
                        AllowBanner = x.Package.AllowBanner,
                        BadgeType = x.Package.BadgeType,
                        HasAnalytics = x.Package.HasAnalytics,
                        IsHighlighted = x.Package.IsHighlighted,
                        IsActive = x.IsActive == true && x.EndDate >= DateTime.UtcNow,
                        StartDate = x.StartDate,
                        EndDate = x.EndDate,
                        PaymentId = x.PaymentId,
                        PaymentStatus = x.Payment?.Status?.StatusName,
                        PaidAt = x.Payment?.PaidAt
                    })
                    .ToList()
            };

            ViewData["Title"] = "Chi tiết tin đăng";
            return View(model);
        }

        [HttpPost("listings/{id:long}/approve")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ApproveListing(long id)
        {
            var listing = await _context.Listings
                .Include(x => x.Status)
                .FirstOrDefaultAsync(x => x.ListingId == id);

            if (listing == null)
            {
                return NotFound();
            }

            if (string.IsNullOrWhiteSpace(listing.Image0))
            {
                TempData["AdminError"] = "Tin đăng chưa có ảnh bìa nên chưa thể duyệt. Vui lòng từ chối và yêu cầu người đăng bổ sung ảnh.";
                return RedirectToAction(nameof(Listings));
            }

            var activeStatusId = await GetListingStatusIdAsync(ListingStatusActive);
            listing.StatusId = activeStatusId;
            listing.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            await _listingRealtimeNotifier.NotifyListingsChangedAsync(
                listing.ListingId,
                "approved",
                ListingStatusActive);

            try
            {
                await _notificationService.CreateAndSendAsync(
                    listing.LandlordId,
                    "Tin đăng đã được duyệt",
                    $"Tin \"{listing.Title}\" đã được duyệt và đang hiển thị.",
                    "listing_approved",
                    listing.ListingId,
                    "listing");

                TempData["AdminSuccess"] = "Đã duyệt tin đăng và gửi thông báo cho người đăng.";
            }
            catch (Exception ex)
            {
                TempData["AdminError"] = $"Tin đăng đã được duyệt, nhưng gửi thông báo thất bại: {ex.Message}";
            }

            return RedirectToAction(nameof(Listings));
        }

        [HttpPost("listings/{id:long}/reject")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> RejectListing(long id, [FromForm] string? reason)
        {
            var listing = await _context.Listings
                .FirstOrDefaultAsync(x => x.ListingId == id);

            if (listing == null)
            {
                return NotFound();
            }

            var rejectedStatusId = await GetListingStatusIdAsync(ListingStatusRejected);
            listing.StatusId = rejectedStatusId;
            listing.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            await _listingRealtimeNotifier.NotifyListingsChangedAsync(
                listing.ListingId,
                "rejected",
                ListingStatusRejected);

            var rejectedReason = string.IsNullOrWhiteSpace(reason)
                ? "Tin đăng chưa đáp ứng tiêu chuẩn nội dung. Vui lòng kiểm tra lại thông tin, hình ảnh và giá phòng."
                : reason.Trim();

            try
            {
                await _notificationService.CreateAndSendAsync(
                    listing.LandlordId,
                    "Tin đăng bị từ chối",
                    $"Tin \"{listing.Title}\" đã bị từ chối. Lý do: {rejectedReason}",
                    "listing_rejected",
                    listing.ListingId,
                    "listing");

                TempData["AdminSuccess"] = "Đã từ chối tin đăng và gửi thông báo cho người đăng.";
            }
            catch (Exception ex)
            {
                TempData["AdminError"] = $"Tin đăng đã bị từ chối, nhưng gửi thông báo thất bại: {ex.Message}";
            }

            return RedirectToAction(nameof(Listings));
        }

        [HttpGet("viewing-appointments")]
        public async Task<IActionResult> ViewingAppointments([FromQuery] string? status)
        {
            var query = _context.ViewingAppointments
                .Include(x => x.Listing)
                .Include(x => x.Tenant)
                .Include(x => x.Landlord)
                .AsQueryable();

            if (!string.IsNullOrWhiteSpace(status))
            {
                var normalizedStatus = status.Trim().ToLowerInvariant();
                query = query.Where(x => x.Status == normalizedStatus);
            }

            var appointments = await query
                .OrderBy(x => x.Status == "pending" ? 0 : 1)
                .ThenBy(x => x.ScheduledAt)
                .Take(500)
                .Select(x => new AdminViewingAppointmentItemViewModel
                {
                    AppointmentId = x.AppointmentId,
                    ListingId = x.ListingId,
                    ListingTitle = x.Listing.Title,
                    TenantName = x.Tenant.FullName,
                    TenantPhone = x.Tenant.Phone,
                    LandlordName = x.Landlord.FullName,
                    LandlordPhone = x.Landlord.Phone,
                    ScheduledAt = x.ScheduledAt,
                    Status = x.Status,
                    TenantNote = x.TenantNote,
                    LandlordNote = x.LandlordNote,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

            ViewData["Title"] = "Lịch xem phòng";
            return View(new AdminViewingAppointmentsViewModel
            {
                Status = status,
                Appointments = appointments
            });
        }

        [HttpGet("reports")]
        public async Task<IActionResult> Reports()
        {
            var reports = await _context.Reports
                .Include(x => x.Reporter)
                .Include(x => x.User)
                .Include(x => x.Listing)
                .Where(x => x.Status == ReportStatusPending)
                .OrderByDescending(x => x.CreatedAt)
                .Select(x => new AdminReportItemViewModel
                {
                    ReportId = x.ReportId,
                    Reason = x.Reason,
                    Description = x.Description,
                    ReporterName = x.Reporter.FullName,
                    TargetUserName = x.User != null ? x.User.FullName : null,
                    ListingTitle = x.Listing != null ? x.Listing.Title : null,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

            ViewData["Title"] = "Xử lý Báo cáo";
            return View(new AdminReportsViewModel { Reports = reports });
        }

        [HttpGet("revenue")]
        public async Task<IActionResult> Revenue([FromQuery] DateOnly? from, [FromQuery] DateOnly? to)
        {
            var today = DateOnly.FromDateTime(DateTime.UtcNow);
            var fromDate = from ?? today.AddDays(-29);
            var toDate = to ?? today;

            if (fromDate > toDate)
            {
                (fromDate, toDate) = (toDate, fromDate);
            }

            var fromDateTime = fromDate.ToDateTime(TimeOnly.MinValue);
            var toDateTimeExclusive = toDate.AddDays(1).ToDateTime(TimeOnly.MinValue);

            var invoices = await _context.Invoices
                .Include(x => x.Status)
                .Include(x => x.Landlord)
                .Include(x => x.Listing)
                .Include(x => x.Payments)
                    .ThenInclude(x => x.Method)
                .Where(x => x.CreatedAt != null && x.CreatedAt >= fromDateTime && x.CreatedAt < toDateTimeExclusive)
                .OrderByDescending(x => x.CreatedAt)
                .Take(500)
                .ToListAsync();

            var successInvoices = invoices
                .Where(x => string.Equals(x.Status.StatusName, PaymentStatusSuccess, StringComparison.OrdinalIgnoreCase))
                .ToList();
            var pendingInvoices = invoices
                .Where(x => string.Equals(x.Status.StatusName, "pending", StringComparison.OrdinalIgnoreCase))
                .ToList();

            var labels = Enumerable.Range(0, toDate.DayNumber - fromDate.DayNumber + 1)
                .Select(i => fromDate.AddDays(i))
                .ToList();

            var revenueByDate = successInvoices
                .Where(x => x.UpdatedAt != null)
                .GroupBy(x => DateOnly.FromDateTime(x.UpdatedAt!.Value))
                .ToDictionary(x => x.Key, x => x.Sum(i => i.TotalAmount));

            var model = new AdminRevenueViewModel
            {
                FromDate = fromDate,
                ToDate = toDate,
                TotalRevenue = successInvoices.Sum(x => x.TotalAmount),
                PendingRevenue = pendingInvoices.Sum(x => x.TotalAmount),
                PaidInvoiceCount = successInvoices.Count,
                PendingInvoiceCount = pendingInvoices.Count,
                AveragePaidInvoice = successInvoices.Count == 0 ? 0 : successInvoices.Average(x => x.TotalAmount),
                ChartLabels = labels.Select(x => x.ToString("dd/MM")).ToList(),
                ChartRevenue = labels
                    .Select(day => revenueByDate.TryGetValue(day, out var amount) ? amount : 0m)
                    .ToList(),
                Invoices = invoices.Select(x =>
                {
                    var latestPayment = x.Payments
                        .OrderByDescending(p => p.PaidAt ?? p.CreatedAt)
                        .FirstOrDefault();

                    return new AdminRevenueInvoiceItemViewModel
                    {
                        InvoiceId = x.InvoiceId,
                        InvoiceCode = x.InvoiceCode,
                        InvoiceType = x.InvoiceType,
                        TotalAmount = x.TotalAmount,
                        StatusName = x.Status.StatusName,
                        DueDate = x.DueDate,
                        CreatedAt = x.CreatedAt,
                        PaidAt = latestPayment?.PaidAt,
                        LandlordName = x.Landlord.FullName,
                        LandlordEmail = x.Landlord.Email,
                        ListingId = x.ListingId,
                        ListingTitle = x.Listing?.Title,
                        PaymentMethod = latestPayment?.Method.MethodName
                    };
                }).ToList()
            };

            ViewData["Title"] = "Quản lý doanh thu";
            return View(model);
        }

        [HttpGet("revenue/invoices/{id:long}")]
        public async Task<IActionResult> RevenueInvoiceDetail(long id)
        {
            var model = await BuildRevenueInvoiceDetailAsync(id);
            if (model == null)
            {
                return NotFound();
            }

            ViewData["Title"] = "Chi tiết bill";
            return View(model);
        }

        [HttpGet("revenue/invoices/{id:long}/export")]
        public async Task<IActionResult> ExportRevenueInvoiceBill(long id)
        {
            var model = await BuildRevenueInvoiceDetailAsync(id);
            if (model == null)
            {
                return NotFound();
            }

            var content = BuildInvoiceBillText(model);
            var fileName = $"{SanitizeFileName(model.InvoiceCode)}_bill.txt";
            return File(System.Text.Encoding.UTF8.GetBytes(content), "text/plain; charset=utf-8", fileName);
        }

        [HttpPost("reports/{id:long}/resolve")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ResolveReport(long id)
        {
            var report = await _context.Reports.FirstOrDefaultAsync(x => x.ReportId == id);
            if (report == null)
            {
                return NotFound();
            }

            report.Status = ReportStatusResolved;
            report.ResolvedAt = DateTime.UtcNow;
            report.ResolvedBy = GetCurrentAdminIdOrNull();
            await _context.SaveChangesAsync();

            await EnsureReportResolvedNotificationAsync(report);

            return RedirectToAction(nameof(Reports));
        }

        private async Task EnsureReportResolvedNotificationAsync(Report report)
        {
            var exists = await _context.Notifications.AnyAsync(x =>
                x.UserId == report.ReporterId &&
                x.NotifType == "report_resolved" &&
                x.RefType == "report" &&
                x.RefId == report.ReportId);

            if (exists)
            {
                return;
            }

            _context.Notifications.Add(new Notification
            {
                UserId = report.ReporterId,
                Title = "Báo cáo đã được xử lý",
                Body = "Cảm ơn bạn đã gửi báo cáo. Chúng tôi xin lỗi vì sự cố bạn gặp phải và đã xử lý vấn đề này.",
                NotifType = "report_resolved",
                RefId = report.ReportId,
                RefType = "report",
                IsRead = false,
                FcmStatus = "pending",
                SentAt = DateTime.UtcNow
            });

            await _context.SaveChangesAsync();
        }

        [HttpPost("reports/{id:long}/dismiss")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DismissReport(long id)
        {
            var report = await _context.Reports.FirstOrDefaultAsync(x => x.ReportId == id);
            if (report == null)
            {
                return NotFound();
            }

            report.Status = ReportStatusDismissed;
            report.ResolvedAt = DateTime.UtcNow;
            report.ResolvedBy = GetCurrentAdminIdOrNull();
            await _context.SaveChangesAsync();

            return RedirectToAction(nameof(Reports));
        }

        [HttpGet("storage")]
        public async Task<IActionResult> Storage(
            [FromQuery(Name = "ref_type")] string? refType,
            [FromQuery(Name = "user_id")] long? userId,
            [FromQuery(Name = "sync")] bool sync = false)
        {
            if (sync)
            {
                await BackfillListingStorageFilesAsync();
                TempData["AdminSuccess"] = "Đã đồng bộ lại danh sách ảnh storage.";
                return RedirectToAction(nameof(Storage), new { ref_type = refType, user_id = userId });
            }

            var query = _context.CloudinaryFiles
                .AsNoTracking()
                .Include(x => x.User)
                .Where(x => x.IsActive == true);

            if (!string.IsNullOrWhiteSpace(refType))
            {
                var normalizedRefType = refType.Trim().ToLowerInvariant();
                query = query.Where(x => x.RefType != null && x.RefType.ToLower() == normalizedRefType);
            }

            if (userId.HasValue)
            {
                query = query.Where(x => x.UserId == userId.Value);
            }

            var files = await query
                .OrderByDescending(x => x.CreatedAt)
                .Take(100)
                .Select(x => new AdminStorageFileItemViewModel
                {
                    FileId = x.FileId,
                    UserId = x.UserId,
                    UserName = x.User.FullName,
                    PublicId = x.PublicId,
                    SecureUrl = x.SecureUrl,
                    ResourceType = x.ResourceType,
                    FileSizeKb = x.FileSizeKb,
                    Format = x.Format,
                    RefType = x.RefType,
                    RefId = x.RefId,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

            foreach (var file in files)
            {
                file.PreviewUrl = ToAdminStoragePreviewUrl(file.SecureUrl, file.PublicId, file.Format, Request);
            }

            ViewData["Title"] = "Quản lý Cloudinary Storage";
            return View(new AdminStorageViewModel
            {
                RefType = refType,
                UserId = userId,
                Files = files
            });
        }

        [HttpPost("storage/{id:long}/delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteStorageFile(long id, [FromQuery(Name = "ref_type")] string? refType, [FromQuery(Name = "user_id")] long? userId)
        {
            var file = await _context.CloudinaryFiles
                .FirstOrDefaultAsync(x => x.FileId == id && x.IsActive == true);

            if (file == null)
            {
                return NotFound();
            }

            await _cloudinaryStorageHelper.DeleteFileAsync(file.PublicId);
            file.IsActive = false;
            file.DeletedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return RedirectToAction(nameof(Storage), new { ref_type = refType, user_id = userId });
        }

        // ==========================================
        // QUẢN LÝ TIỆN ÍCH (AMENITY CRUD)
        // ==========================================

        // Lấy danh sách tất cả tiện ích (cả hoạt động và không hoạt động)
        [HttpGet("amenities")]
        public async Task<IActionResult> Amenities()
        {
            // Tự động cập nhật tiếng Việt có dấu cho các tiện ích mặc định nếu chưa có dấu
            var defaultAmenities = new Dictionary<string, (string Name, string Category)>
            {
                { "wifi", ("Wifi", "basic") },
                { "dieu hoa", ("Điều hòa", "comfort") },
                { "may giat", ("Máy giặt", "basic") },
                { "tu lanh", ("Tủ lạnh", "basic") },
                { "bep", ("Bếp", "basic") },
                { "bai xe", ("Bãi xe", "basic") },
                { "camera an ninh", ("Camera an ninh", "security") },
                { "thang may", ("Thang máy", "comfort") },
                { "ho boi", ("Hồ bơi", "comfort") },
                { "gym", ("Gym", "comfort") },
                { "ban cong", ("Ban công", "comfort") },
                { "noi that day du", ("Nội thất đầy đủ", "comfort") },
                { "cua tu", ("Cửa từ", "security") },
                { "bao ve 24/7", ("Bảo vệ 24/7", "security") },
                { "cho nuoi thu cung", ("Cho nuôi thú cưng", "basic") }
            };

            bool isUpdated = false;
            foreach (var item in defaultAmenities)
            {
                // Tìm tiện ích theo tên không dấu cũ (hoặc gần giống)
                var amenity = await _context.Amenities
                    .FirstOrDefaultAsync(x => x.Name.ToLower() == item.Key || x.Name.ToLower() == item.Value.Name.ToLower());
                
                if (amenity != null)
                {
                    // Nếu tên chưa đúng có dấu hoặc Category chưa chuẩn, cập nhật lại
                    if (amenity.Name != item.Value.Name || amenity.Category != item.Value.Category)
                    {
                        amenity.Name = item.Value.Name;
                        amenity.Category = item.Value.Category;
                        isUpdated = true;
                    }
                }
            }

            if (isUpdated)
            {
                await _context.SaveChangesAsync();
            }

            // Query toàn bộ tiện ích sắp xếp theo ID giảm dần để tiện ích mới thêm hiển thị lên đầu
            var amenities = await _context.Amenities
                .OrderByDescending(x => x.AmenityId)
                .ToListAsync();

            ViewData["Title"] = "Quản lý Tiện ích";
            return View(amenities);
        }

        // Thêm tiện ích mới
        [HttpPost("amenities/create")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> CreateAmenity(string name, string? category, string? iconUrl, IFormFile? iconFile)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                TempData["AdminError"] = "Tên tiện ích không được để trống.";
                return RedirectToAction(nameof(Amenities));
            }

            // Tránh trùng tên
            var exists = await _context.Amenities.AnyAsync(x => x.Name.ToLower() == name.Trim().ToLower());
            if (exists)
            {
                TempData["AdminError"] = $"Tiện ích '{name}' đã tồn tại trong hệ thống.";
                return RedirectToAction(nameof(Amenities));
            }

            var amenity = new Amenity
            {
                Name = name.Trim(),
                Category = category?.Trim(),
                IsActive = true
            };

            // Nếu người dùng chọn file ảnh tải lên
            if (iconFile != null && iconFile.Length > 0)
            {
                try
                {
                    var extension = Path.GetExtension(iconFile.FileName).ToLowerInvariant();
                    var fileName = $"{Guid.NewGuid():N}{extension}";
                    var webRoot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
                    var dirPath = Path.Combine(webRoot, "uploads", "amenities");
                    Directory.CreateDirectory(dirPath);

                    var filePath = Path.Combine(dirPath, fileName);
                    using (var stream = System.IO.File.Create(filePath))
                    {
                        await iconFile.CopyToAsync(stream);
                    }

                    amenity.IconUrl = $"/uploads/amenities/{fileName}";
                }
                catch (Exception ex)
                {
                    TempData["AdminError"] = $"Không thể tải ảnh tiện ích lên: {ex.Message}";
                    return RedirectToAction(nameof(Amenities));
                }
            }
            else
            {
                // Nếu không có file thì dùng chuỗi text định danh (như ac_unit, wifi...)
                amenity.IconUrl = iconUrl?.Trim();
            }

            await _context.Amenities.AddAsync(amenity);
            await _context.SaveChangesAsync();

            TempData["AdminSuccess"] = $"Đã thêm tiện ích '{name}' thành công.";
            return RedirectToAction(nameof(Amenities));
        }

        // Chỉnh sửa tiện ích có sẵn
        [HttpPost("amenities/edit")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> EditAmenity(int id, string name, string? category, string? iconUrl, IFormFile? iconFile, bool isActive)
        {
            var amenity = await _context.Amenities.FirstOrDefaultAsync(x => x.AmenityId == id);
            if (amenity == null)
            {
                TempData["AdminError"] = "Không tìm thấy tiện ích cần chỉnh sửa.";
                return RedirectToAction(nameof(Amenities));
            }

            if (string.IsNullOrWhiteSpace(name))
            {
                TempData["AdminError"] = "Tên tiện ích không được bỏ trống.";
                return RedirectToAction(nameof(Amenities));
            }

            // Tránh trùng tên với tiện ích khác
            var exists = await _context.Amenities.AnyAsync(x => x.AmenityId != id && x.Name.ToLower() == name.Trim().ToLower());
            if (exists)
            {
                TempData["AdminError"] = $"Tên tiện ích '{name}' trùng với một tiện ích khác đã có.";
                return RedirectToAction(nameof(Amenities));
            }

            amenity.Name = name.Trim();
            amenity.Category = category?.Trim();
            amenity.IsActive = isActive;

            // Xử lý upload ảnh mới
            if (iconFile != null && iconFile.Length > 0)
            {
                try
                {
                    var extension = Path.GetExtension(iconFile.FileName).ToLowerInvariant();
                    var fileName = $"{Guid.NewGuid():N}{extension}";
                    var webRoot = Path.Combine(Directory.GetCurrentDirectory(), "wwwroot");
                    var dirPath = Path.Combine(webRoot, "uploads", "amenities");
                    Directory.CreateDirectory(dirPath);

                    var filePath = Path.Combine(dirPath, fileName);
                    using (var stream = System.IO.File.Create(filePath))
                    {
                        await iconFile.CopyToAsync(stream);
                    }

                    amenity.IconUrl = $"/uploads/amenities/{fileName}";
                }
                catch (Exception ex)
                {
                    TempData["AdminError"] = $"Lỗi khi cập nhật ảnh mới: {ex.Message}";
                    return RedirectToAction(nameof(Amenities));
                }
            }
            else
            {
                // Cập nhật text icon nếu có nhập mới
                if (!string.IsNullOrWhiteSpace(iconUrl))
                {
                    amenity.IconUrl = iconUrl.Trim();
                }
            }

            await _context.SaveChangesAsync();

            TempData["AdminSuccess"] = $"Đã cập nhật tiện ích '{amenity.Name}' thành công.";
            return RedirectToAction(nameof(Amenities));
        }

        // Bật/tắt trạng thái hoạt động nhanh
        [HttpPost("amenities/{id:int}/toggle-active")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> ToggleAmenityActive(int id)
        {
            var amenity = await _context.Amenities.FirstOrDefaultAsync(x => x.AmenityId == id);
            if (amenity == null)
            {
                TempData["AdminError"] = "Không tìm thấy tiện ích.";
                return RedirectToAction(nameof(Amenities));
            }

            amenity.IsActive = !(amenity.IsActive ?? false);
            await _context.SaveChangesAsync();

            var trangThai = (amenity.IsActive == true) ? "kích hoạt" : "hủy kích hoạt";
            TempData["AdminSuccess"] = $"Đã {trangThai} tiện ích '{amenity.Name}' thành công.";
            return RedirectToAction(nameof(Amenities));
        }

        // Xóa hẳn tiện ích
        [HttpPost("amenities/{id:int}/delete")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> DeleteAmenity(int id)
        {
            var amenity = await _context.Amenities.FirstOrDefaultAsync(x => x.AmenityId == id);
            if (amenity == null)
            {
                TempData["AdminError"] = "Không tìm thấy tiện ích cần xóa.";
                return RedirectToAction(nameof(Amenities));
            }

            // Chặn xóa nếu tiện ích đã được dùng trong phòng trọ (tránh lỗi khóa ngoại DB)
            var dangSuDung = await _context.ListingAmenities.AnyAsync(x => x.AmenityId == id);
            if (dangSuDung)
            {
                TempData["AdminError"] = $"Không thể xóa tiện ích '{amenity.Name}' vì đã được liên kết với tin đăng phòng. Hãy tắt hoạt động thay vì xóa.";
                return RedirectToAction(nameof(Amenities));
            }

            _context.Amenities.Remove(amenity);
            await _context.SaveChangesAsync();

            TempData["AdminSuccess"] = $"Đã xóa tiện ích '{amenity.Name}' thành công.";
            return RedirectToAction(nameof(Amenities));
        }

        // ==========================================
        // GỬI THÔNG BÁO THỦ CÔNG (MANUAL NOTIFICATIONS)
        // ==========================================

        // API tìm kiếm nhanh người dùng bằng AJAX cho Form gửi thông báo
        [HttpGet("users/search")]
        public async Task<IActionResult> SearchUsers(string q)
        {
            if (string.IsNullOrWhiteSpace(q))
            {
                return Json(new List<object>());
            }

            var keyword = q.Trim().ToLowerInvariant();
            var users = await _context.Users
                .Include(x => x.Role)
                .Where(x => x.IsActive == true 
                    && x.Role.RoleName.ToLower() != RoleAdmin
                    && ((x.FullName != null && x.FullName.ToLower().Contains(keyword))
                        || (x.Email != null && x.Email.ToLower().Contains(keyword))
                        || (x.Phone != null && x.Phone.Contains(keyword))))
                .Take(20)
                .Select(x => new
                {
                    userId = x.UserId,
                    fullName = x.FullName,
                    email = x.Email ?? "",
                    phone = x.Phone ?? ""
                })
                .ToListAsync();

            return Json(users);
        }

        // Trang soạn và gửi thông báo
        [HttpGet("notifications/send")]
        public async Task<IActionResult> SendNotification(long? targetUserId)
        {
            ViewData["Title"] = "Gửi thông báo thủ công";
            ViewBag.TargetUserId = targetUserId;
            if (targetUserId.HasValue)
            {
                var targetUser = await _context.Users.FirstOrDefaultAsync(x => x.UserId == targetUserId.Value);
                if (targetUser != null)
                {
                    ViewBag.TargetUserFullName = targetUser.FullName;
                    ViewBag.TargetUserEmail = targetUser.Email;
                }
            }
            return View();
        }

        // Xử lý gửi thông báo thủ công
        [HttpPost("notifications/send")]
        [ValidateAntiForgeryToken]
        public async Task<IActionResult> SendNotification(string targetType, long? userId, string title, string body)
        {
            if (string.IsNullOrWhiteSpace(title) || string.IsNullOrWhiteSpace(body))
            {
                TempData["AdminError"] = "Vui lòng nhập đầy đủ cả tiêu đề và nội dung thông báo.";
                return RedirectToAction(nameof(SendNotification), new { targetUserId = userId });
            }

            // Tập hợp ID các user cần gửi
            var recipientIds = new List<long>();

            if (targetType == "single")
            {
                if (!userId.HasValue)
                {
                    TempData["AdminError"] = "Vui lòng chọn người nhận cụ thể.";
                    return RedirectToAction(nameof(SendNotification));
                }
                var userExists = await _context.Users.AnyAsync(x => x.UserId == userId.Value && x.IsActive == true);
                if (!userExists)
                {
                    TempData["AdminError"] = "Người dùng được chọn không tồn tại hoặc tài khoản đã bị khóa.";
                    return RedirectToAction(nameof(SendNotification));
                }
                recipientIds.Add(userId.Value);
            }
            else if (targetType == "all")
            {
                recipientIds = await _context.Users
                    .Where(x => x.IsActive == true && x.Role.RoleName.ToLower() != RoleAdmin)
                    .Select(x => x.UserId)
                    .ToListAsync();
            }
            else if (targetType == "landlords")
            {
                recipientIds = await _context.Users
                    .Where(x => x.IsActive == true && x.Role.RoleName.ToLower() == RoleLandlord)
                    .Select(x => x.UserId)
                    .ToListAsync();
            }
            else if (targetType == "tenants")
            {
                recipientIds = await _context.Users
                    .Where(x => x.IsActive == true && x.Role.RoleName.ToLower() == RoleTenant)
                    .Select(x => x.UserId)
                    .ToListAsync();
            }
            else
            {
                TempData["AdminError"] = "Đối tượng nhận thông báo không hợp lệ.";
                return RedirectToAction(nameof(SendNotification));
            }

            if (!recipientIds.Any())
            {
                TempData["AdminError"] = "Không tìm thấy người dùng nào khớp với bộ lọc.";
                return RedirectToAction(nameof(SendNotification));
            }

            // Thực hiện lưu DB và gửi push notification qua service
            int successCount = 0;
            foreach (var id in recipientIds)
            {
                // Gửi và lưu DB (sử dụng loại thông báo 'system_announcement')
                var result = await _notificationService.CreateAndSendAsync(
                    id,
                    title.Trim(),
                    body.Trim(),
                    "system_announcement",
                    refId: null,
                    refType: "admin"
                );
                if (result) successCount++;
            }

            TempData["AdminSuccess"] = $"Đã gửi thông báo thành công tới {successCount}/{recipientIds.Count} tài khoản.";
            return RedirectToAction(nameof(SendNotification));
        }

        private async Task BackfillListingStorageFilesAsync()
        {
            var listings = await _context.Listings
                .AsNoTracking()
                .Where(x => x.Image0 != null || x.Image1 != null || x.Image2 != null || x.Image3 != null || x.Image4 != null || x.Image5 != null)
                .Select(x => new
                {
                    x.ListingId,
                    x.LandlordId,
                    Images = new[] { x.Image0, x.Image1, x.Image2, x.Image3, x.Image4, x.Image5 }
                })
                .ToListAsync();

            var changed = false;
            foreach (var listing in listings)
            {
                foreach (var imageUrl in listing.Images.Where(x => !string.IsNullOrWhiteSpace(x)).Select(x => x!.Trim()).Distinct())
                {
                    if (!TryBuildStoragePublicId(imageUrl, listing.ListingId, out var publicId, out var format))
                    {
                        continue;
                    }

                    var exists = await _context.CloudinaryFiles.AnyAsync(x =>
                        x.PublicId == publicId &&
                        x.RefType == "listing" &&
                        x.RefId == listing.ListingId &&
                        x.IsActive == true);

                    if (exists)
                    {
                        continue;
                    }

                    await _context.CloudinaryFiles.AddAsync(new CloudinaryFile
                    {
                        UserId = listing.LandlordId,
                        PublicId = publicId,
                        SecureUrl = imageUrl,
                        DeliveryUrl = imageUrl,
                        ResourceType = "image",
                        Format = format,
                        Folder = $"uploads/listings/{listing.ListingId}",
                        RefType = "listing",
                        RefId = listing.ListingId,
                        IsActive = true,
                        UploadStatus = "uploaded",
                        CreatedAt = DateTime.UtcNow
                    });
                    changed = true;
                }
            }

            if (changed)
            {
                await _context.SaveChangesAsync();
            }
        }

        private async Task<AdminRevenueInvoiceDetailViewModel?> BuildRevenueInvoiceDetailAsync(long invoiceId)
        {
            var invoice = await _context.Invoices
                .Include(x => x.Status)
                .Include(x => x.Landlord)
                .Include(x => x.Listing)
                .Include(x => x.Payments)
                    .ThenInclude(x => x.Method)
                .FirstOrDefaultAsync(x => x.InvoiceId == invoiceId);

            if (invoice == null)
            {
                return null;
            }

            var latestPayment = invoice.Payments
                .OrderByDescending(x => x.PaidAt ?? x.CreatedAt)
                .FirstOrDefault();

            return new AdminRevenueInvoiceDetailViewModel
            {
                InvoiceId = invoice.InvoiceId,
                InvoiceCode = invoice.InvoiceCode,
                InvoiceType = invoice.InvoiceType,
                TotalAmount = invoice.TotalAmount,
                StatusName = invoice.Status.StatusName,
                DueDate = invoice.DueDate,
                CreatedAt = invoice.CreatedAt,
                UpdatedAt = invoice.UpdatedAt,
                PaidAt = latestPayment?.PaidAt,
                LandlordName = invoice.Landlord.FullName,
                LandlordEmail = invoice.Landlord.Email,
                ListingId = invoice.ListingId,
                ListingTitle = invoice.Listing?.Title,
                PaymentMethod = latestPayment?.Method.MethodName,
                Note = invoice.Note
            };
        }

        private static string BuildInvoiceBillText(AdminRevenueInvoiceDetailViewModel model)
        {
            var lines = new List<string>
            {
                "SWINGS HOUSE - BI?N LAI THANH TO?N",
                "--------------------------------",
                $"M? h?a ??n: {model.InvoiceCode}",
                $"Lo?i h?a ??n: {model.InvoiceType}",
                $"Tr?ng th?i: {model.StatusName}",
                $"S? ti?n: {model.TotalAmount:N0} d",
                $"Ng??i thanh to?n: {model.LandlordName}",
                $"Email: {model.LandlordEmail ?? "-"}",
                $"Ng?y t?o: {model.CreatedAt?.ToLocalTime():dd/MM/yyyy HH:mm}",
                $"H?n thanh to?n: {model.DueDate:dd/MM/yyyy}",
                $"Ng?y thanh to?n: {(model.PaidAt.HasValue ? model.PaidAt.Value.ToLocalTime().ToString("dd/MM/yyyy HH:mm") : "-")}",
                $"Ph??ng th?c: {model.PaymentMethod ?? "-"}"
            };

            if (model.ListingId.HasValue)
            {
                lines.Add($"Tin ??ng: #{model.ListingId} - {model.ListingTitle ?? "-"}");
            }

            if (!string.IsNullOrWhiteSpace(model.Note))
            {
                lines.Add($"Ghi ch?: {model.Note.Trim()}");
            }

            lines.Add("--------------------------------");
            lines.Add("Cam on ban da su dung SWINGS HOUSE.");

            return string.Join(Environment.NewLine, lines);
        }

        private static string SanitizeFileName(string value)
        {
            var invalidChars = Path.GetInvalidFileNameChars();
            var sanitized = new string(value.Select(ch => invalidChars.Contains(ch) ? '_' : ch).ToArray());
            return string.IsNullOrWhiteSpace(sanitized) ? "invoice" : sanitized;
        }

        private static string? ToAdminImageUrl(string? imageUrl)
        {
            if (string.IsNullOrWhiteSpace(imageUrl))
            {
                return null;
            }

            var value = imageUrl.Trim();
            if (Uri.TryCreate(value, UriKind.Absolute, out var uri) &&
                uri.AbsolutePath.StartsWith("/uploads/", StringComparison.OrdinalIgnoreCase))
            {
                return uri.AbsolutePath;
            }

            return value;
        }

        private static string? ToAdminStoragePreviewUrl(string? secureUrl, string? publicId, string? format, HttpRequest request)
        {
            var value = !string.IsNullOrWhiteSpace(secureUrl)
                ? secureUrl.Trim()
                : publicId?.Trim();

            if (string.IsNullOrWhiteSpace(value))
            {
                return null;
            }

            if (Uri.TryCreate(value, UriKind.Absolute, out var absoluteUri))
            {
                if (absoluteUri.AbsolutePath.StartsWith("/uploads/", StringComparison.OrdinalIgnoreCase))
                {
                    var normalizedPath = AppendImageFormatIfMissing(absoluteUri.AbsolutePath, absoluteUri.AbsolutePath, format);
                    return $"{request.Scheme}://{request.Host}{normalizedPath}";
                }

                return value;
            }

            var path = value.StartsWith("/", StringComparison.Ordinal) ? value : $"/{value}";
            return path.StartsWith("/uploads/", StringComparison.OrdinalIgnoreCase)
                ? $"{request.Scheme}://{request.Host}{AppendImageFormatIfMissing(path, path, format)}"
                : path;
        }

        private static string AppendImageFormatIfMissing(string value, string path, string? format)
        {
            if (Path.HasExtension(path) || string.IsNullOrWhiteSpace(format))
            {
                return value;
            }

            var normalizedFormat = format.Trim().TrimStart('.');
            if (string.IsNullOrWhiteSpace(normalizedFormat))
            {
                return value;
            }

            var queryIndex = value.IndexOf('?', StringComparison.Ordinal);
            if (queryIndex < 0)
            {
                return $"{value}.{normalizedFormat}";
            }

            return $"{value[..queryIndex]}.{normalizedFormat}{value[queryIndex..]}";
        }

        private static bool TryBuildStoragePublicId(string imageUrl, long listingId, out string publicId, out string? format)
        {
            publicId = string.Empty;
            format = null;

            var path = imageUrl;
            if (Uri.TryCreate(imageUrl, UriKind.Absolute, out var uri))
            {
                path = uri.AbsolutePath;
            }

            var marker = $"/uploads/listings/{listingId}/";
            var markerIndex = path.IndexOf(marker, StringComparison.OrdinalIgnoreCase);
            if (markerIndex < 0)
            {
                return false;
            }

            var relativePath = path[(markerIndex + 1)..];
            var extension = Path.GetExtension(relativePath);
            format = string.IsNullOrWhiteSpace(extension)
                ? null
                : extension.TrimStart('.').ToLowerInvariant();
            publicId = string.IsNullOrWhiteSpace(extension)
                ? relativePath
                : relativePath[..^extension.Length];
            return !string.IsNullOrWhiteSpace(publicId);
        }

        private async Task<int> GetListingStatusIdAsync(string statusName)
        {
            var status = await _context.ListingStatuses
                .FirstOrDefaultAsync(x => x.StatusName == statusName);

            if (status == null)
            {
                throw new InvalidOperationException($"Không tìm thấy trạng thái ListingStatus = '{statusName}'.");
            }

            return status.StatusId;
        }

        private async Task SyncUserRolesByListingsAsync()
        {
            var roleIds = await _context.Roles
                .Where(x =>
                    x.RoleName.ToLower() == RoleTenant ||
                    x.RoleName.ToLower() == RoleLandlord)
                .ToDictionaryAsync(x => x.RoleName.ToLower(), x => x.RoleId);

            if (!roleIds.TryGetValue(RoleTenant, out var tenantRoleId) ||
                !roleIds.TryGetValue(RoleLandlord, out var landlordRoleId))
            {
                return;
            }

            var usersWithListings = (await _context.Listings
                    .Select(x => x.LandlordId)
                    .Distinct()
                    .ToListAsync())
                .ToHashSet();

            var users = await _context.Users
                .Include(x => x.Role)
                .Where(x => x.Role.RoleName.ToLower() != RoleAdmin)
                .ToListAsync();

            var changed = false;
            foreach (var user in users)
            {
                var targetRoleId = usersWithListings.Contains(user.UserId)
                    ? landlordRoleId
                    : tenantRoleId;

                if (user.RoleId == targetRoleId)
                {
                    continue;
                }

                user.RoleId = targetRoleId;
                user.UpdatedAt = DateTime.UtcNow;
                changed = true;
            }

            if (changed)
            {
                await _context.SaveChangesAsync();
            }
        }

        private long? GetCurrentAdminIdOrNull()
        {
            var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            return long.TryParse(idClaim, out var id) ? id : null;
        }

        private static string GetFirebaseDisplayName(ExportedUserRecord firebaseUser)
        {
            if (!string.IsNullOrWhiteSpace(firebaseUser.DisplayName))
            {
                return firebaseUser.DisplayName;
            }

            if (!string.IsNullOrWhiteSpace(firebaseUser.Email))
            {
                return firebaseUser.Email;
            }

            return "Firebase User";
        }

        private static string GetFirebaseProvider(ExportedUserRecord firebaseUser)
        {
            var provider = firebaseUser.ProviderData.FirstOrDefault()?.ProviderId;
            return string.IsNullOrWhiteSpace(provider) ? "firebase" : provider;
        }

        private static string GetAvatarSource(string provider)
        {
            if (provider.Contains("google", StringComparison.OrdinalIgnoreCase))
            {
                return "google";
            }

            if (provider.Contains("facebook", StringComparison.OrdinalIgnoreCase))
            {
                return "facebook";
            }

            return "default";
        }

        private static string? NormalizeEmail(string? email)
        {
            return string.IsNullOrWhiteSpace(email) ? null : email.Trim().ToLowerInvariant();
        }

        private static string? Truncate(string? value, int maxLength)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return value;
            }

            return value.Length <= maxLength ? value : value[..maxLength];
        }

        private static string TruncateRequired(string value, int maxLength)
        {
            return value.Length <= maxLength ? value : value[..maxLength];
        }

        private async Task<bool> CanUseEmailAsync(string? email, string firebaseUid, long? currentUserId = null)
        {
            if (email == null)
            {
                return false;
            }

            return !await _context.Users.AnyAsync(x =>
                x.Email == email
                && x.UserId != currentUserId
                && x.FirebaseUid != firebaseUid);
        }

        private async Task EnsureUserPreferenceAsync(User user)
        {
            if (user.UserPreference != null
                || await _context.UserPreferences.AnyAsync(x => x.UserId == user.UserId))
            {
                return;
            }

            _context.UserPreferences.Add(new UserPreference
            {
                UserId = user.UserId,
                OnboardingDone = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
        }

        private async Task TryAutoSyncFirebaseUsersAsync()
        {
            if (FirebaseApp.DefaultInstance == null)
            {
                return;
            }

            try
            {
                await SyncFirebaseUsersToSqlAsync();
            }
            catch (Exception ex)
            {
                var detail = ex.InnerException?.Message ?? ex.Message;
                TempData["AdminError"] = $"Tự động đồng bộ Firebase thất bại: {detail}";
            }
        }

        private async Task<(int CreatedCount, int UpdatedCount, int SkippedCount)> SyncFirebaseUsersToSqlAsync()
        {
            if (FirebaseApp.DefaultInstance == null)
            {
                throw new InvalidOperationException("Firebase Admin chưa được cấu hình. Hãy thêm file firebase-adminsdk.json rồi chạy lại backend.");
            }

            var createdCount = 0;
            var updatedCount = 0;
            var skippedCount = 0;

            await EnsureNullableUserUniqueIndexesAsync();

            await foreach (var firebaseUser in FirebaseAuth.DefaultInstance.ListUsersAsync(null))
            {
                if (string.IsNullOrWhiteSpace(firebaseUser.Uid))
                {
                    skippedCount++;
                    continue;
                }

                var provider = TruncateRequired(GetFirebaseProvider(firebaseUser), 30);
                var email = NormalizeEmail(firebaseUser.Email);
                if (email?.Length > 150)
                {
                    email = null;
                }

                var firebaseUid = TruncateRequired(firebaseUser.Uid, 128);
                var user = await _context.Users
                    .Include(x => x.UserPreference)
                    .FirstOrDefaultAsync(x => x.FirebaseUid == firebaseUid);

                if (user == null && email != null)
                {
                    user = await _context.Users
                        .Include(x => x.UserPreference)
                        .FirstOrDefaultAsync(x => x.Email == email && (x.FirebaseUid == null || x.FirebaseUid == ""));
                }

                if (user == null)
                {
                    user = new User
                    {
                        FullName = TruncateRequired(GetFirebaseDisplayName(firebaseUser), 100),
                        Email = await CanUseEmailAsync(email, firebaseUid) ? email : null,
                        PasswordHash = null,
                        AvatarUrl = Truncate(firebaseUser.PhotoUrl, 500),
                        RoleId = 2,
                        IsVerified = firebaseUser.EmailVerified,
                        IsActive = !firebaseUser.Disabled,
                        FirebaseUid = firebaseUid,
                        FirebaseProvider = provider,
                        AvatarSource = GetAvatarSource(provider),
                        CreatedAt = DateTime.UtcNow,
                        UpdatedAt = DateTime.UtcNow
                    };

                    _context.Users.Add(user);
                    await _context.SaveChangesAsync();
                    await EnsureUserPreferenceAsync(user);
                    createdCount++;
                }
                else
                {
                    user.FullName = string.IsNullOrWhiteSpace(firebaseUser.DisplayName)
                        ? user.FullName
                        : TruncateRequired(firebaseUser.DisplayName, 100);
                    user.Email = await CanUseEmailAsync(email, firebaseUid, user.UserId) ? email : user.Email;
                    user.AvatarUrl = string.IsNullOrWhiteSpace(firebaseUser.PhotoUrl) ? user.AvatarUrl : Truncate(firebaseUser.PhotoUrl, 500);
                    user.IsVerified = firebaseUser.EmailVerified;
                    user.IsActive = !firebaseUser.Disabled;
                    user.FirebaseUid = firebaseUid;
                    user.FirebaseProvider = provider;
                    user.AvatarSource = GetAvatarSource(provider);
                    user.UpdatedAt = DateTime.UtcNow;

                    await EnsureUserPreferenceAsync(user);
                    updatedCount++;
                }
            }

            await _context.SaveChangesAsync();
            return (createdCount, updatedCount, skippedCount);
        }

        private async Task EnsureNullableUserUniqueIndexesAsync()
        {
            const string sql = """
DECLARE @sql NVARCHAR(MAX) = N'';

SELECT @sql += N'ALTER TABLE dbo.Users DROP CONSTRAINT ' + QUOTENAME(kc.name) + N';'
FROM sys.key_constraints kc
JOIN sys.index_columns ic
    ON kc.parent_object_id = ic.object_id
    AND kc.unique_index_id = ic.index_id
JOIN sys.columns c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
WHERE kc.parent_object_id = OBJECT_ID(N'dbo.Users')
  AND kc.type = 'UQ'
  AND c.name IN (N'email', N'phone', N'firebase_uid');

IF @sql <> N''
BEGIN
    EXEC sp_executesql @sql;
END;

IF EXISTS (
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Users')
      AND name = N'IX_Users_FirebaseUid'
      AND is_unique = 0
)
BEGIN
    DROP INDEX IX_Users_FirebaseUid ON dbo.Users;
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Users')
      AND name = N'UX_Users_Email_NotNull'
)
BEGIN
    CREATE UNIQUE INDEX UX_Users_Email_NotNull
        ON dbo.Users(email)
        WHERE email IS NOT NULL;
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Users')
      AND name = N'UX_Users_Phone_NotNull'
)
BEGIN
    CREATE UNIQUE INDEX UX_Users_Phone_NotNull
        ON dbo.Users(phone)
        WHERE phone IS NOT NULL;
END;

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'dbo.Users')
      AND name = N'UX_Users_FirebaseUid_NotNull'
)
BEGIN
    CREATE UNIQUE INDEX UX_Users_FirebaseUid_NotNull
        ON dbo.Users(firebase_uid)
        WHERE firebase_uid IS NOT NULL;
END;
""";

            await _context.Database.ExecuteSqlRawAsync(sql);
        }
    }
}

