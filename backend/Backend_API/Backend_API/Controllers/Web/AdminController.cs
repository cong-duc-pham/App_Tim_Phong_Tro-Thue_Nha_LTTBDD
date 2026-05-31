using System.Security.Claims;
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
            await TryAutoSyncFirebaseUsersAsync();

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
                    Image0 = x.Image0,
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
        public async Task<IActionResult> ListingDetail(long id)
        {
            var listing = await _context.Listings
                .Include(x => x.Status)
                .Include(x => x.Type)
                .Include(x => x.Landlord)
                .Include(x => x.Province)
                .Include(x => x.District)
                .Include(x => x.Ward)
                .Include(x => x.ListingImages)
                .Include(x => x.ListingAmenities)
                    .ThenInclude(x => x.Amenity)
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
                .Select(x => x!)
                .ToList();

            imageUrls.AddRange(listing.ListingImages
                .OrderByDescending(x => x.IsCover == true)
                .ThenBy(x => x.SortOrder)
                .Select(x => string.IsNullOrWhiteSpace(x.SecureUrl) ? x.CloudinaryUrl : x.SecureUrl!)
                .Where(x => !string.IsNullOrWhiteSpace(x)));

            var model = new AdminListingDetailViewModel
            {
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
                Amenities = listing.ListingAmenities
                    .Select(x => x.Amenity.Name)
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .OrderBy(x => x)
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
            await BackfillListingStorageFilesAsync();

            var query = _context.CloudinaryFiles
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

