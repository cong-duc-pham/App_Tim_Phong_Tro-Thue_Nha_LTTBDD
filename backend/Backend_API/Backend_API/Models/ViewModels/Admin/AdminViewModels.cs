namespace Backend_API.Models.ViewModels.Admin;

public class AdminDashboardViewModel
{
    public int TotalUsers { get; set; }
    public int TotalFirebaseUsers { get; set; }
    public int TotalActiveListings { get; set; }
    public decimal RevenueThisMonth { get; set; }
    public int FcmSentCount { get; set; }
    public int FcmFailedCount { get; set; }
    public List<string> Last30DayLabels { get; set; } = new();
    public List<int> NewUsers30Days { get; set; } = new();
    public List<decimal> Revenue30Days { get; set; } = new();
}

public class AdminUserItemViewModel
{
    public long UserId { get; set; }
    public string FullName { get; set; } = string.Empty;
    public string? Email { get; set; }
    public string RoleName { get; set; } = string.Empty;
    public string? FirebaseUid { get; set; }
    public string AuthMethod { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}

public class AdminUsersViewModel
{
    public List<AdminUserItemViewModel> Users { get; set; } = new();
}

public class AdminListingItemViewModel
{
    public long ListingId { get; set; }
    public string Title { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public string LandlordName { get; set; } = string.Empty;
    public string? LandlordEmail { get; set; }
    public string StatusName { get; set; } = string.Empty;
    public string? Image0 { get; set; }
    public int? ViewCount { get; set; }
    public int? SaveCount { get; set; }
    public DateTime? CreatedAt { get; set; }
}

public class AdminListingsViewModel
{
    public List<AdminListingItemViewModel> Listings { get; set; } = new();
}

public class AdminListingManagementViewModel
{
    public string? Status { get; set; }
    public string? Keyword { get; set; }
    public List<string> Statuses { get; set; } = new();
    public List<AdminListingItemViewModel> Listings { get; set; } = new();
}

public class AdminListingDetailViewModel
{
    public bool IsManagementContext { get; set; }
    public long ListingId { get; set; }
    public string Title { get; set; } = string.Empty;
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public decimal Area { get; set; }
    public int? Floor { get; set; }
    public int? TotalFloors { get; set; }
    public int? MaxOccupants { get; set; }
    public string RoomType { get; set; } = string.Empty;
    public string StatusName { get; set; } = string.Empty;
    public string StreetAddress { get; set; } = string.Empty;
    public string? WardName { get; set; }
    public string? DistrictName { get; set; }
    public string? ProvinceName { get; set; }
    public bool? AllowPet { get; set; }
    public bool? IsVerified { get; set; }
    public bool? IsFeatured { get; set; }
    public bool? IsNew { get; set; }
    public decimal? ElectricPrice { get; set; }
    public decimal? WaterPrice { get; set; }
    public decimal? InternetPrice { get; set; }
    public decimal? ParkingPrice { get; set; }
    public int? ViewCount { get; set; }
    public int? SaveCount { get; set; }
    public DateOnly? AvailableFrom { get; set; }
    public DateTime? ExpiredAt { get; set; }
    public DateTime? CreatedAt { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public string LandlordName { get; set; } = string.Empty;
    public string? LandlordEmail { get; set; }
    public string? LandlordPhone { get; set; }
    public string? LandlordFirebaseUid { get; set; }
    public List<string> ImageUrls { get; set; } = new();
    public List<AdminListingVideoViewModel> Videos { get; set; } = new();
    public List<string> Amenities { get; set; } = new();
    public List<AdminListingPackageViewModel> Packages { get; set; } = new();
}

public class AdminListingVideoViewModel
{
    public long VideoId { get; set; }
    public string Url { get; set; } = string.Empty;
    public string? ThumbnailUrl { get; set; }
    public int? DurationSec { get; set; }
    public int? FileSizeKb { get; set; }
    public DateTime? CreatedAt { get; set; }
}

public class AdminListingPackageViewModel
{
    public string PackageName { get; set; } = string.Empty;
    public string PackageType { get; set; } = string.Empty;
    public decimal Price { get; set; }
    public int Priority { get; set; }
    public int MaxImages { get; set; }
    public int MaxVideos { get; set; }
    public bool AllowBanner { get; set; }
    public string? BadgeType { get; set; }
    public bool HasAnalytics { get; set; }
    public bool IsHighlighted { get; set; }
    public bool IsActive { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public long? PaymentId { get; set; }
    public string? PaymentStatus { get; set; }
    public DateTime? PaidAt { get; set; }
}

public class AdminReportItemViewModel
{
    public long ReportId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string? Description { get; set; }
    public string ReporterName { get; set; } = string.Empty;
    public string? TargetUserName { get; set; }
    public string? ListingTitle { get; set; }
    public DateTime? CreatedAt { get; set; }
}

public class AdminReportsViewModel
{
    public List<AdminReportItemViewModel> Reports { get; set; } = new();
}

public class AdminStorageFileItemViewModel
{
    public long FileId { get; set; }
    public long UserId { get; set; }
    public string UserName { get; set; } = string.Empty;
    public string PublicId { get; set; } = string.Empty;
    public string SecureUrl { get; set; } = string.Empty;
    public string ResourceType { get; set; } = string.Empty;
    public int? FileSizeKb { get; set; }
    public string? Format { get; set; }
    public string? RefType { get; set; }
    public long? RefId { get; set; }
    public DateTime? CreatedAt { get; set; }
}

public class AdminStorageViewModel
{
    public string? RefType { get; set; }
    public long? UserId { get; set; }
    public List<AdminStorageFileItemViewModel> Files { get; set; } = new();
}
