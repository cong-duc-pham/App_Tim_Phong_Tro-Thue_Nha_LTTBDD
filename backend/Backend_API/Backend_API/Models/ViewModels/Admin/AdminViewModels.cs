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
    public DateTime? CreatedAt { get; set; }
}

public class AdminListingsViewModel
{
    public List<AdminListingItemViewModel> Listings { get; set; } = new();
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
