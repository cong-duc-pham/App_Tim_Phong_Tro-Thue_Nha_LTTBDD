using System.Security.Claims;
using Backend_API.Helpers;
using Backend_API.Models.Entities;
using Backend_API.Models.ViewModels.Admin;
using Backend_API.Services.Interfaces;
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

        private readonly PhongTroDbContext _context;
        private readonly INotificationService _notificationService;
        private readonly CloudinaryStorageHelper _cloudinaryStorageHelper;

        public AdminController(
            PhongTroDbContext context,
            INotificationService notificationService,
            CloudinaryStorageHelper cloudinaryStorageHelper)
        {
            _context = context;
            _notificationService = notificationService;
            _cloudinaryStorageHelper = cloudinaryStorageHelper;
        }

        [HttpGet("dashboard")]
        public async Task<IActionResult> Dashboard()
        {
            var today = DateTime.UtcNow.Date;
            var startDate = today.AddDays(-29);
            var monthStart = new DateTime(today.Year, today.Month, 1);

            var dailyStats = await _context.DailyStats
                .Where(x => x.StatDate >= DateOnly.FromDateTime(startDate) && x.StatDate <= DateOnly.FromDateTime(today))
                .OrderBy(x => x.StatDate)
                .ToListAsync();

            var labels = Enumerable.Range(0, 30)
                .Select(i => startDate.AddDays(i))
                .ToList();

            var statByDate = dailyStats.ToDictionary(x => x.StatDate);

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
                    return statByDate.TryGetValue(key, out var stat) ? (stat.NewUsers ?? 0) : 0;
                }).ToList(),
                Revenue30Days = labels.Select(day =>
                {
                    var key = DateOnly.FromDateTime(day);
                    return statByDate.TryGetValue(key, out var stat) ? (stat.TotalRevenue ?? 0m) : 0m;
                }).ToList()
            };

            ViewData["Title"] = "Dashboard";
            return View(model);
        }

        [HttpGet("users")]
        public async Task<IActionResult> Users()
        {
            var users = await _context.VwUserFirebaseInfos
                .OrderByDescending(x => x.UserId)
                .Select(x => new AdminUserItemViewModel
                {
                    UserId = x.UserId,
                    FullName = x.FullName,
                    Email = x.Email,
                    RoleName = x.RoleName,
                    FirebaseUid = x.FirebaseUid,
                    AuthMethod = x.AuthMethod,
                    IsActive = x.IsActive == true
                })
                .ToListAsync();

            ViewData["Title"] = "Quản lý Users";
            return View(new AdminUsersViewModel { Users = users });
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

            ViewData["Title"] = "Duyệt Tin Đăng";
            return View(new AdminListingsViewModel { Listings = listings });
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

            var activeStatusId = await GetListingStatusIdAsync(ListingStatusActive);
            listing.StatusId = activeStatusId;
            listing.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            await _notificationService.CreateAndSendAsync(
                listing.LandlordId,
                "Tin đã được duyệt",
                $"Tin \"{listing.Title}\" đã được duyệt và đang hiển thị.",
                "listing_approved",
                listing.ListingId,
                "listing");

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

            var rejectedReason = string.IsNullOrWhiteSpace(reason) ? "Chưa đáp ứng tiêu chuẩn nội dung." : reason.Trim();
            await _notificationService.CreateAndSendAsync(
                listing.LandlordId,
                "Tin bị từ chối",
                $"Tin \"{listing.Title}\" bị từ chối. Lý do: {rejectedReason}",
                "listing_rejected",
                listing.ListingId,
                "listing");

            return RedirectToAction(nameof(Listings));
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

            return RedirectToAction(nameof(Reports));
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
        public async Task<IActionResult> Storage([FromQuery(Name = "ref_type")] string? refType, [FromQuery(Name = "user_id")] long? userId)
        {
            var query = _context.FirebaseStorageFiles
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
                .Take(300)
                .Select(x => new AdminStorageFileItemViewModel
                {
                    FileId = x.FileId,
                    UserId = x.UserId,
                    UserName = x.User.FullName,
                    StoragePath = x.StoragePath,
                    FileType = x.FileType,
                    FileSizeKb = x.FileSizeKb,
                    MimeType = x.MimeType,
                    RefType = x.RefType,
                    RefId = x.RefId,
                    CreatedAt = x.CreatedAt
                })
                .ToListAsync();

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
            var file = await _context.FirebaseStorageFiles
                .FirstOrDefaultAsync(x => x.FileId == id && x.IsActive == true);

            if (file == null)
            {
                return NotFound();
            }

            await _cloudinaryStorageHelper.DeleteFileAsync(file.StoragePath);
            file.IsActive = false;
            file.DeletedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return RedirectToAction(nameof(Storage), new { ref_type = refType, user_id = userId });
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

        private long? GetCurrentAdminIdOrNull()
        {
            var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
            return long.TryParse(idClaim, out var id) ? id : null;
        }
    }
}
