using Backend_API.Helpers;
using Backend_API.Models.DTOs.Listings;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class ListingService : IListingService
    {
        private readonly PhongTroDbContext _context;

        // StatusId cứng (tra cứu từ bảng ListingStatuses)
        private const int STATUS_ACTIVE = 1;
        private const int STATUS_PENDING = 2;
        private const int STATUS_HIDDEN = 5;

        public ListingService(PhongTroDbContext context)
        {
            _context = context;
        }

        // ─────────────────────────────────────────────
        // CREATE
        // ─────────────────────────────────────────────
        public async Task<ListingResponseDto> CreateListingAsync(long landlordId, ListingCreateDto dto)
        {
            // Tạo Listing mới
            await PromoteUserToLandlordIfNeeded(landlordId);

            var hasCoverImage = !string.IsNullOrWhiteSpace(dto.Image0);

            var listing = new Listing
            {
                LandlordId   = landlordId,
                TypeId       = dto.TypeId,
                // Business rule: nếu chưa có ảnh cover thì để pending chờ bổ sung/duyệt
                StatusId     = hasCoverImage ? STATUS_ACTIVE : STATUS_PENDING,
                Title        = dto.Title,
                Description  = dto.Description,
                Price        = dto.Price,
                Area         = dto.Area,
                Floor        = dto.Floor,
                TotalFloors  = dto.TotalFloors,
                MaxOccupants = dto.MaxOccupants,
                ProvinceId   = dto.ProvinceId,
                DistrictId   = dto.DistrictId,
                WardId       = dto.WardId,
                StreetAddress = dto.StreetAddress,
                Latitude     = dto.Latitude,
                Longitude    = dto.Longitude,
                Image0       = dto.Image0,
                Image1       = dto.Image1,
                Image2       = dto.Image2,
                Image3       = dto.Image3,
                Image4       = dto.Image4,
                Image5       = dto.Image5,
                CloudinaryFolder = dto.CloudinaryFolder,
                ElectricPrice = dto.ElectricPrice,
                WaterPrice   = dto.WaterPrice,
                InternetPrice = dto.InternetPrice,
                ParkingPrice = dto.ParkingPrice,
                AllowPet     = dto.AllowPet,
                AvailableFrom = dto.AvailableFrom,
                IsVerified   = false,
                IsFeatured   = false,
                IsNew        = true,
                ViewCount    = 0,
                SaveCount    = 0,
                CreatedAt    = DateTime.UtcNow,
                UpdatedAt    = DateTime.UtcNow
            };

            await _context.Listings.AddAsync(listing);
            await _context.SaveChangesAsync(); // Lấy ListingId

            // Insert ListingAmenities
            if (dto.AmenityIds.Count > 0)
            {
                var amenities = dto.AmenityIds.Select(aId => new ListingAmenity
                {
                    ListingId = listing.ListingId,
                    AmenityId = aId
                });
                await _context.ListingAmenities.AddRangeAsync(amenities);
            }

            // Ghi nhận các Cloudinary files (ref_type='listing')
            var imageFiles = new[] { dto.Image0, dto.Image1, dto.Image2, dto.Image3, dto.Image4, dto.Image5 }
                            .Where(url => !string.IsNullOrEmpty(url))
                            .Select(url =>
                            {
                                var publicId = ExtractPublicIdFromCloudinaryUrl(url!);
                                return new CloudinaryFile
                                {
                                    UserId = landlordId,
                                    PublicId = publicId,
                                    SecureUrl = url!,
                                    DeliveryUrl = url!,
                                    ResourceType = "image",
                                    Format = GetFormatFromUrl(url!),
                                    Folder = GetFolderFromPublicId(publicId),
                                    RefType = "listing",
                                    RefId = listing.ListingId,
                                    IsActive = true,
                                    UploadStatus = "uploaded",
                                    CreatedAt = DateTime.UtcNow
                                };
                            });
            await _context.CloudinaryFiles.AddRangeAsync(imageFiles);

            await _context.SaveChangesAsync();

            return await BuildResponseDto(listing.ListingId)
                   ?? throw new Exception("Tạo tin đăng thất bại.");
        }

        // ─────────────────────────────────────────────
        // UPDATE
        // ─────────────────────────────────────────────
        private async Task PromoteUserToLandlordIfNeeded(long userId)
        {
            var user = await _context.Users
                .Include(u => u.Role)
                .FirstOrDefaultAsync(u => u.UserId == userId);
            if (user == null) return;

            var currentRole = user.Role?.RoleName?.Trim().ToLower();
            if (currentRole == "admin" || currentRole == "landlord") return;

            var landlordRoleId = await _context.Roles
                .Where(r => r.RoleName.ToLower() == "landlord")
                .Select(r => r.RoleId)
                .FirstOrDefaultAsync();
            if (landlordRoleId == 0) return;

            user.RoleId = landlordRoleId;
            user.UpdatedAt = DateTime.UtcNow;
        }

        public async Task<ListingResponseDto> UpdateListingAsync(long listingId, ListingUpdateDto dto)
        {
            var listing = await _context.Listings.FindAsync(listingId)
                          ?? throw new Exception("Không tìm thấy tin đăng.");

            // Chỉ cập nhật các field không null
            if (dto.Title        != null) listing.Title        = dto.Title;
            if (dto.Description  != null) listing.Description  = dto.Description;
            if (dto.Price        != null) listing.Price        = dto.Price.Value;
            if (dto.Area         != null) listing.Area         = dto.Area.Value;
            if (dto.TypeId       != null) listing.TypeId       = dto.TypeId.Value;
            if (dto.ProvinceId   != null) listing.ProvinceId   = dto.ProvinceId;
            if (dto.DistrictId   != null) listing.DistrictId   = dto.DistrictId;
            if (dto.WardId       != null) listing.WardId       = dto.WardId;
            if (dto.StreetAddress != null) listing.StreetAddress = dto.StreetAddress;
            if (dto.Latitude     != null) listing.Latitude     = dto.Latitude;
            if (dto.Longitude    != null) listing.Longitude    = dto.Longitude;
            if (dto.Image0 != null) listing.Image0 = dto.Image0;
            if (dto.Image1 != null) listing.Image1 = dto.Image1;
            if (dto.Image2 != null) listing.Image2 = dto.Image2;
            if (dto.Image3 != null) listing.Image3 = dto.Image3;
            if (dto.Image4 != null) listing.Image4 = dto.Image4;
            if (dto.Image5 != null) listing.Image5 = dto.Image5;
            if (dto.ElectricPrice  != null) listing.ElectricPrice  = dto.ElectricPrice;
            if (dto.WaterPrice     != null) listing.WaterPrice     = dto.WaterPrice;
            if (dto.InternetPrice  != null) listing.InternetPrice  = dto.InternetPrice;
            if (dto.ParkingPrice   != null) listing.ParkingPrice   = dto.ParkingPrice;
            if (dto.Floor          != null) listing.Floor          = dto.Floor;
            if (dto.TotalFloors    != null) listing.TotalFloors    = dto.TotalFloors;
            if (dto.MaxOccupants   != null) listing.MaxOccupants   = dto.MaxOccupants;
            if (dto.AllowPet       != null) listing.AllowPet       = dto.AllowPet;
            if (dto.AvailableFrom  != null) listing.AvailableFrom  = dto.AvailableFrom;

            listing.UpdatedAt = DateTime.UtcNow;

            // Cập nhật tiện ích nếu client gửi lên danh sách mới
            if (dto.AmenityIds != null)
            {
                var old = _context.ListingAmenities.Where(la => la.ListingId == listingId);
                _context.ListingAmenities.RemoveRange(old);

                var newAmenities = dto.AmenityIds.Select(aId => new ListingAmenity
                {
                    ListingId = listingId,
                    AmenityId = aId
                });
                await _context.ListingAmenities.AddRangeAsync(newAmenities);
            }

            await _context.SaveChangesAsync();
            return await BuildResponseDto(listingId)
                   ?? throw new Exception("Cập nhật tin đăng thất bại.");
        }

        // ─────────────────────────────────────────────
        // DELETE (Soft delete)
        // ─────────────────────────────────────────────
        public async Task DeleteListingAsync(long listingId)
        {
            var listing = await _context.Listings.FindAsync(listingId)
                          ?? throw new Exception("Không tìm thấy tin đăng.");

            // Soft delete: đổi status sang 'hidden'
            listing.StatusId  = STATUS_HIDDEN;
            listing.UpdatedAt = DateTime.UtcNow;

            // Đánh dấu toàn bộ file ảnh là inactive → Background Job sẽ xóa sau 24h
            var files = await _context.CloudinaryFiles
                .Where(f => f.RefType == "listing" && f.RefId == listingId && f.IsActive == true)
                .ToListAsync();

            foreach (var file in files)
            {
                file.IsActive  = false;
                file.DeletedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();
        }

        public async Task<ListingResponseDto> ToggleListingStatusAsync(long listingId, long landlordId)
        {
            var listing = await _context.Listings.FindAsync(listingId)
                          ?? throw new Exception("Không tìm thấy tin đăng.");

            if (listing.LandlordId != landlordId)
                throw new UnauthorizedAccessException("Bạn không phải chủ sở hữu bài đăng này.");

            if (listing.StatusId == STATUS_ACTIVE)
            {
                listing.StatusId = STATUS_HIDDEN;
            }
            else if (listing.StatusId == STATUS_HIDDEN)
            {
                listing.StatusId = STATUS_ACTIVE;
            }
            else
            {
                throw new Exception("Chỉ bài đăng đang hoạt động hoặc đang tạm ẩn mới có thể thay đổi trạng thái.");
            }

            listing.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            return await BuildResponseDto(listingId)
                   ?? throw new Exception("Cập nhật tin đăng thất bại.");
        }

        // ─────────────────────────────────────────────
        // GET BY ID
        // ─────────────────────────────────────────────
        public async Task<ListingResponseDto?> GetListingByIdAsync(long listingId)
        {
            return await BuildResponseDto(listingId);
        }

        // ─────────────────────────────────────────────
        // SEARCH / FILTER (có phân trang + ưu tiên VIP)
        // ─────────────────────────────────────────────
        public async Task<(List<ListingResponseDto> Items, int TotalCount)> GetListingsAsync(ListingFilterDto filter)
        {
            // Chỉ lấy tin đang active
            var query = _context.Listings
                .Include(l => l.Type)
                .Include(l => l.Status)
                .Include(l => l.District)
                .Include(l => l.Province)
                .Include(l => l.Ward)
                .Include(l => l.Landlord)
                .Include(l => l.ListingAmenities)
                    .ThenInclude(la => la.Amenity)
                .Include(l => l.ListingPostPackages)
                    .ThenInclude(lpp => lpp.Package)
                .Include(l => l.Reviews)
                .Where(l => l.StatusId == STATUS_ACTIVE)
                .AsQueryable();

            // ── Filters
            if (!string.IsNullOrEmpty(filter.Keyword))
            {
                var kw = filter.Keyword.ToLower();
                query = query.Where(l => l.Title.ToLower().Contains(kw)
                                      || (l.StreetAddress != null && l.StreetAddress.ToLower().Contains(kw)));
            }
            if (filter.MinPrice    != null) query = query.Where(l => l.Price >= filter.MinPrice);
            if (filter.MaxPrice    != null) query = query.Where(l => l.Price <= filter.MaxPrice);
            if (filter.MinArea     != null) query = query.Where(l => l.Area  >= filter.MinArea);
            if (filter.MaxArea     != null) query = query.Where(l => l.Area  <= filter.MaxArea);
            if (filter.ProvinceId  != null) query = query.Where(l => l.ProvinceId == filter.ProvinceId);
            if (filter.DistrictId  != null) query = query.Where(l => l.DistrictId == filter.DistrictId);
            if (filter.WardId      != null) query = query.Where(l => l.WardId     == filter.WardId);
            if (filter.TypeId      != null) query = query.Where(l => l.TypeId     == filter.TypeId);
            if (filter.AllowPet    != null) query = query.Where(l => l.AllowPet   == filter.AllowPet);
            if (filter.IsVerified  != null) query = query.Where(l => l.IsVerified == filter.IsVerified);
            if (filter.IsFeatured  != null) query = query.Where(l => l.IsFeatured == filter.IsFeatured);

            // ── Lọc theo tiện ích (phải có TẤT CẢ amenity được yêu cầu)
            if (filter.AmenityIds != null && filter.AmenityIds.Count > 0)
            {
                foreach (var aId in filter.AmenityIds)
                {
                    query = query.Where(l => l.ListingAmenities.Any(la => la.AmenityId == aId));
                }
            }

            // ── Geo-filter theo bán kính (tính xấp xỉ bằng bounding box)
            if (filter.Latitude != null && filter.Longitude != null && filter.RadiusKm != null)
            {
                double latDelta = filter.RadiusKm.Value / 111.0;
                double lngDelta = filter.RadiusKm.Value / (111.0 * Math.Cos(filter.Latitude.Value * Math.PI / 180.0));
                query = query.Where(l =>
                    l.Latitude  != null && l.Longitude != null &&
                    l.Latitude  >= filter.Latitude  - latDelta &&
                    l.Latitude  <= filter.Latitude  + latDelta &&
                    l.Longitude >= filter.Longitude - lngDelta &&
                    l.Longitude <= filter.Longitude + lngDelta);
            }

            int total = await query.CountAsync();

            // ── Sắp xếp: VIP (Priority cao) lên trước, sau đó theo tiêu chí người dùng
            var now = DateTime.UtcNow;
            IOrderedQueryable<Listing> ordered;

            switch (filter.SortBy?.ToLower())
            {
                case "price_asc":
                    ordered = query
                        .OrderByDescending(l => l.ListingPostPackages
                            .Where(p => p.IsActive == true && p.EndDate > now)
                            .Max(p => (int?)p.Package.Priority) ?? 0)
                        .ThenBy(l => l.Price);
                    break;
                case "price_desc":
                    ordered = query
                        .OrderByDescending(l => l.ListingPostPackages
                            .Where(p => p.IsActive == true && p.EndDate > now)
                            .Max(p => (int?)p.Package.Priority) ?? 0)
                        .ThenByDescending(l => l.Price);
                    break;
                case "rating":
                    ordered = query
                        .OrderByDescending(l => l.ListingPostPackages
                            .Where(p => p.IsActive == true && p.EndDate > now)
                            .Max(p => (int?)p.Package.Priority) ?? 0)
                        .ThenByDescending(l => l.Reviews.Any()
                            ? l.Reviews.Average(r => (double?)r.Rating) : 0);
                    break;
                default: // "newest"
                    ordered = query
                        .OrderByDescending(l => l.ListingPostPackages
                            .Where(p => p.IsActive == true && p.EndDate > now)
                            .Max(p => (int?)p.Package.Priority) ?? 0)
                        .ThenByDescending(l => l.CreatedAt);
                    break;
            }

            // ── Phân trang
            var pageSize  = Math.Clamp(filter.PageSize, 1, 50);
            var pageIndex = Math.Max(filter.Page - 1, 0);

            var listings = await ordered
                .Skip(pageIndex * pageSize)
                .Take(pageSize)
                .ToListAsync();

            var items = listings.Select(MapToResponseDto).ToList();
            return (items, total);
        }

        // ─────────────────────────────────────────────
        // MY LISTINGS
        // ─────────────────────────────────────────────
        public async Task<List<ListingResponseDto>> GetMyListingsAsync(long landlordId)
        {
            var listings = await _context.Listings
                .Include(l => l.Type)
                .Include(l => l.Status)
                .Include(l => l.District)
                .Include(l => l.Province)
                .Include(l => l.Ward)
                .Include(l => l.Landlord)
                .Include(l => l.ListingAmenities).ThenInclude(la => la.Amenity)
                .Include(l => l.ListingPostPackages).ThenInclude(lpp => lpp.Package)
                .Include(l => l.Reviews)
                .Where(l => l.LandlordId == landlordId)
                .OrderByDescending(l => l.CreatedAt)
                .ToListAsync();

            return listings.Select(MapToResponseDto).ToList();
        }

        // ─────────────────────────────────────────────
        // INCREMENT VIEW COUNT
        // ─────────────────────────────────────────────
        public async Task IncrementViewCountAsync(long listingId)
        {
            var listing = await _context.Listings.FindAsync(listingId);
            if (listing == null) return;
            listing.ViewCount = (listing.ViewCount ?? 0) + 1;
            await _context.SaveChangesAsync();
        }

        // ─────────────────────────────────────────────
        // PRIVATE HELPERS
        // ─────────────────────────────────────────────

        /// <summary>Load đầy đủ 1 listing bằng ID rồi map sang DTO.</summary>
        private async Task<ListingResponseDto?> BuildResponseDto(long listingId)
        {
            var listing = await _context.Listings
                .Include(l => l.Type)
                .Include(l => l.Status)
                .Include(l => l.District)
                .Include(l => l.Province)
                .Include(l => l.Ward)
                .Include(l => l.Landlord)
                .Include(l => l.ListingAmenities).ThenInclude(la => la.Amenity)
                .Include(l => l.ListingPostPackages).ThenInclude(lpp => lpp.Package)
                .Include(l => l.Reviews)
                .FirstOrDefaultAsync(l => l.ListingId == listingId);

            return listing == null ? null : MapToResponseDto(listing);
        }

        /// <summary>Map Entity Listing → ListingResponseDto.</summary>
        private static ListingResponseDto MapToResponseDto(Listing l)
        {
            var now = DateTime.UtcNow;

            // Gói VIP đang kích hoạt (ưu tiên Priority cao nhất)
            var activePackage = l.ListingPostPackages
                .Where(p => p.IsActive == true && p.EndDate > now)
                .OrderByDescending(p => p.Package.Priority)
                .FirstOrDefault();

            double avgRating = l.Reviews.Any()
                ? l.Reviews.Average(r => (double)r.Rating)
                : 0;

            return new ListingResponseDto
            {
                ListingId       = l.ListingId,
                LandlordId      = l.LandlordId,
                LandlordName    = l.Landlord?.FullName ?? string.Empty,
                LandlordAvatar  = l.Landlord?.AvatarUrl,
                LandlordPhone   = l.Landlord?.Phone ?? string.Empty,
                Title           = l.Title,
                Description     = l.Description,
                Price           = l.Price,
                Area            = l.Area,
                TypeId          = l.TypeId,
                TypeName        = l.Type?.TypeName ?? string.Empty,
                ProvinceId      = l.ProvinceId,
                ProvinceName    = l.Province?.ProvinceName,
                DistrictId      = l.DistrictId,
                DistrictName    = l.District?.DistrictName,
                WardId          = l.WardId,
                WardName        = l.Ward?.WardName,
                StreetAddress   = l.StreetAddress,
                Latitude        = l.Latitude,
                Longitude       = l.Longitude,
                Image0          = l.Image0,
                Image1          = l.Image1,
                Image2          = l.Image2,
                Image3          = l.Image3,
                Image4          = l.Image4,
                Image5          = l.Image5,
                ElectricPrice   = l.ElectricPrice,
                WaterPrice      = l.WaterPrice,
                InternetPrice   = l.InternetPrice,
                ParkingPrice    = l.ParkingPrice,
                Floor           = l.Floor,
                TotalFloors     = l.TotalFloors,
                MaxOccupants    = l.MaxOccupants,
                AllowPet        = l.AllowPet,
                AvailableFrom   = l.AvailableFrom,
                AmenityNames    = l.ListingAmenities
                                    .Select(la => la.Amenity?.Name ?? string.Empty)
                                    .Where(n => n != string.Empty)
                                    .ToList(),
                StatusName      = l.Status?.StatusName ?? string.Empty,
                IsVerified      = l.IsVerified,
                IsFeatured      = l.IsFeatured,
                ViewCount       = l.ViewCount,
                SaveCount       = l.SaveCount,
                AverageRating   = Math.Round(avgRating, 1),
                ReviewCount     = l.Reviews.Count,
                PackageInfo = activePackage == null ? null : new PackageInfoDto
                {
                    PackageName = activePackage.Package.PackageName,
                    PackageType = activePackage.Package.PackageType,
                    Priority = activePackage.Package.Priority,
                    MaxImages = activePackage.Package.MaxImages,
                    MaxVideos = activePackage.Package.MaxVideos,
                    AllowBanner = activePackage.Package.AllowBanner,
                    BadgeType = activePackage.Package.BadgeType,
                    HasAnalytics = activePackage.Package.HasAnalytics,
                    IsHighlighted = activePackage.Package.IsHighlighted,
                    StartDate   = activePackage.StartDate,
                    EndDate     = activePackage.EndDate,
                    IsActive    = activePackage.IsActive == true
                },
                CreatedAt  = l.CreatedAt,
                ExpiredAt  = l.ExpiredAt
            };
        }

        private static string ExtractPublicIdFromCloudinaryUrl(string url)
        {
            try
            {
                var uri = new Uri(url);
                var path = uri.AbsolutePath.Trim('/');
                var uploadMarker = "/upload/";
                var idx = path.IndexOf(uploadMarker, StringComparison.OrdinalIgnoreCase);
                if (idx >= 0)
                {
                    var rest = path[(idx + uploadMarker.Length)..];
                    if (rest.StartsWith("v") && rest.Contains('/'))
                    {
                        var firstSlash = rest.IndexOf('/');
                        var versionPart = rest[..firstSlash];
                        if (versionPart.Length > 1 && int.TryParse(versionPart[1..], out _))
                        {
                            rest = rest[(firstSlash + 1)..];
                        }
                    }

                    var dotIndex = rest.LastIndexOf('.');
                    return dotIndex > 0 ? rest[..dotIndex] : rest;
                }
            }
            catch
            {
                // ignore
            }

            return url;
        }

        private static string? GetFolderFromPublicId(string publicId)
        {
            var slash = publicId.LastIndexOf('/');
            return slash > 0 ? publicId[..slash] : null;
        }

        private static string? GetFormatFromUrl(string url)
        {
            var dot = url.LastIndexOf('.');
            if (dot < 0 || dot == url.Length - 1) return null;
            var ext = url[(dot + 1)..];
            var q = ext.IndexOf('?');
            if (q >= 0) ext = ext[..q];
            return ext.ToLowerInvariant();
        }
    }
}
