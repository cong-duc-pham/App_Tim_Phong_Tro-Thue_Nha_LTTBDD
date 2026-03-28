namespace Backend_API.Models.DTOs;

// ── AUTH REQUEST / RESPONSE ──────────────────────────────────────

public record RegisterRequest(
    string FullName,
    string Email,
    string Password,
    string? Phone,
    string Role = "tenant"  // tenant | landlord
);

public record LoginRequest(
    string Email,
    string Password
);

public record SendOtpRequest(
    string Email,
    string Purpose  // register | forgot_password | verify
);

public record VerifyOtpRequest(
    string Email,
    string Code,
    string Purpose
);

public record AuthResponse(
    long UserId,
    string FullName,
    string Email,
    string? Phone,
    string? AvatarUrl,
    string RoleName,
    string Token,
    bool OnboardingDone
);

// ── USER - PROFILE / PREFERENCES ────────────────────────────────

public record UserProfileDto(
    long UserId,
    string FullName,
    string? Email,
    string? Phone,
    string? AvatarUrl,
    string? Gender,
    DateTime? DateOfBirth,
    string RoleName,
    bool IsVerified,
    DateTime CreatedAt
);

public record UpdateProfileRequest(
    string? FullName,
    string? Phone,
    string? AvatarUrl,
    byte? Gender,
    DateTime? DateOfBirth
);

public record SavePreferencesRequest(
    string? PreferredArea,
    decimal? MinPrice,
    decimal? MaxPrice,
    bool? AllowPet,
    double? Latitude,
    double? Longitude,
    int SearchRadiusKm = 5
);

// ── LISTING ──────────────────────────────────────────────────────

public record ListingDto(
    long ListingId,
    string Title,
    decimal Price,
    decimal Area,
    string StreetAddress,
    string? DistrictName,
    string? ProvinceName,
    double? Latitude,
    double? Longitude,
    bool IsFeatured,
    bool IsVerified,
    bool AllowPet,
    string? CoverImageUrl,
    string RoomTypeName,
    string StatusName,
    int ViewCount,
    int SaveCount,
    DateTime CreatedAt
);

public record ListingDetailDto(
    long ListingId,
    string Title,
    string? Description,
    decimal Price,
    decimal Area,
    int? Floor,
    int? TotalFloors,
    int MaxOccupants,
    string StreetAddress,
    string? WardName,
    string? DistrictName,
    string? ProvinceName,
    double? Latitude,
    double? Longitude,
    bool IsFeatured,
    bool IsVerified,
    bool IsNew,
    bool AllowPet,
    decimal? ElectricPrice,
    decimal? WaterPrice,
    decimal? InternetPrice,
    decimal? ParkingPrice,
    int ViewCount,
    int SaveCount,
    string RoomTypeName,
    string StatusName,
    string LandlordName,
    string? LandlordPhone,
    string? LandlordAvatar,
    List<string> ImageUrls,
    List<string> AmenityNames,
    DateTime? AvailableFrom,
    DateTime CreatedAt
);

public record CreateListingRequest(
    int TypeId,
    string Title,
    string? Description,
    decimal Price,
    decimal Area,
    int? Floor,
    int? TotalFloors,
    int MaxOccupants,
    int? ProvinceId,
    int? DistrictId,
    int? WardId,
    string StreetAddress,
    double? Latitude,
    double? Longitude,
    bool AllowPet,
    decimal? ElectricPrice,
    decimal? WaterPrice,
    decimal? InternetPrice,
    decimal? ParkingPrice,
    DateTime? AvailableFrom,
    List<int> AmenityIds,
    List<string> ImageUrls
);

public record ListingSearchQuery
{
    public string? Keyword { get; init; }
    public int? TypeId { get; init; }
    public int? DistrictId { get; init; }
    public int? ProvinceId { get; init; }
    public decimal? MinPrice { get; init; }
    public decimal? MaxPrice { get; init; }
    public decimal? MinArea { get; init; }
    public bool? AllowPet { get; init; }
    public double? Lat { get; init; }
    public double? Lng { get; init; }
    public int? RadiusKm { get; init; }
    public string SortBy { get; init; } = "newest";  // newest | price_asc | price_desc | nearest
    public int Page { get; init; } = 1;
    public int PageSize { get; init; } = 20;
}

// ── COMMON ────────────────────────────────────────────────────────

public record PagedResult<T>(
    List<T> Items,
    int TotalCount,
    int Page,
    int PageSize
);

public record ApiResponse<T>(bool Success, string? Message, T? Data);
