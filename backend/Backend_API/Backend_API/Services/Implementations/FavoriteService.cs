using Backend_API.Models.DTOs.Listings;
using Backend_API.Models.Entities;
using Backend_API.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services.Implementations
{
    public class FavoriteService : IFavoriteService
    {
        private readonly PhongTroDbContext _context;
        private const int STATUS_ACTIVE = 1;

        public FavoriteService(PhongTroDbContext context)
        {
            _context = context;
        }

        public async Task<bool> ToggleFavoriteAsync(long userId, long listingId)
        {
            var existing = await _context.Favorites
                .FirstOrDefaultAsync(f => f.UserId == userId && f.ListingId == listingId);

            if (existing != null)
            {
                // Đã yêu thích → bỏ yêu thích + save_count--
                _context.Favorites.Remove(existing);

                var listing = await _context.Listings.FindAsync(listingId);
                if (listing != null)
                    listing.SaveCount = Math.Max((listing.SaveCount ?? 1) - 1, 0);

                await _context.SaveChangesAsync();
                return false; // Hiện tại: không còn yêu thích
            }
            else
            {
                // Chưa yêu thích → thêm + save_count++
                var canFavorite = await _context.Listings
                    .AnyAsync(l => l.ListingId == listingId && l.StatusId == STATUS_ACTIVE);
                if (!canFavorite)
                {
                    throw new InvalidOperationException("Chỉ có thể lưu tin đang hiển thị.");
                }

                await _context.Favorites.AddAsync(new Favorite
                {
                    UserId    = userId,
                    ListingId = listingId,
                    CreatedAt = DateTime.UtcNow
                });

                var listing = await _context.Listings.FindAsync(listingId);
                if (listing != null)
                    listing.SaveCount = (listing.SaveCount ?? 0) + 1;

                await _context.SaveChangesAsync();
                return true; // Hiện tại: đang yêu thích
            }
        }

        public async Task<List<ListingResponseDto>> GetFavoritesAsync(long userId)
        {
            var listings = await _context.Favorites
                .Where(f => f.UserId == userId)
                .Where(f => f.Listing.StatusId == STATUS_ACTIVE)
                .OrderByDescending(f => f.CreatedAt)
                .Include(f => f.Listing).ThenInclude(l => l.Type)
                .Include(f => f.Listing).ThenInclude(l => l.Status)
                .Include(f => f.Listing).ThenInclude(l => l.Province)
                .Include(f => f.Listing).ThenInclude(l => l.District)
                .Include(f => f.Listing).ThenInclude(l => l.Ward)
                .Include(f => f.Listing).ThenInclude(l => l.Landlord)
                .Include(f => f.Listing).ThenInclude(l => l.ListingAmenities)
                    .ThenInclude(la => la.Amenity)
                .Include(f => f.Listing).ThenInclude(l => l.ListingPostPackages)
                    .ThenInclude(lpp => lpp.Package)
                .Include(f => f.Listing).ThenInclude(l => l.Reviews)
                .Select(f => f.Listing)
                .ToListAsync();

            return listings.Select(MapToResponseDto).ToList();
        }

        public async Task<bool> IsFavoriteAsync(long userId, long listingId)
        {
            return await _context.Favorites
                .AnyAsync(f =>
                    f.UserId == userId &&
                    f.ListingId == listingId &&
                    f.Listing.StatusId == STATUS_ACTIVE);
        }

        // ── Reuse mapper (tương đương ListingService.MapToResponseDto)
        private static ListingResponseDto MapToResponseDto(Listing l)
        {
            var now = DateTime.UtcNow;

            var activePackage = l.ListingPostPackages
                .Where(p => p.IsActive == true && p.EndDate > now)
                .OrderByDescending(p => p.Package.Priority)
                .FirstOrDefault();

            double avgRating = l.Reviews.Any()
                ? l.Reviews.Average(r => (double)r.Rating)
                : 0;

            return new ListingResponseDto
            {
                ListingId      = l.ListingId,
                LandlordId     = l.LandlordId,
                LandlordName   = l.Landlord?.FullName ?? string.Empty,
                LandlordAvatar = l.Landlord?.AvatarUrl,
                LandlordPhone  = l.Landlord?.Phone ?? string.Empty,
                Title          = l.Title,
                Description    = l.Description,
                Price          = l.Price,
                Area           = l.Area,
                TypeId         = l.TypeId,
                TypeName       = l.Type?.TypeName ?? string.Empty,
                ProvinceId     = l.ProvinceId,
                ProvinceName   = l.Province?.ProvinceName,
                DistrictId     = l.DistrictId,
                DistrictName   = l.District?.DistrictName,
                WardId         = l.WardId,
                WardName       = l.Ward?.WardName,
                StreetAddress  = l.StreetAddress,
                Latitude       = l.Latitude,
                Longitude      = l.Longitude,
                Image0         = l.Image0,
                Image1         = l.Image1,
                Image2         = l.Image2,
                Image3         = l.Image3,
                Image4         = l.Image4,
                Image5         = l.Image5,
                ElectricPrice  = l.ElectricPrice,
                WaterPrice     = l.WaterPrice,
                InternetPrice  = l.InternetPrice,
                ParkingPrice   = l.ParkingPrice,
                Floor          = l.Floor,
                TotalFloors    = l.TotalFloors,
                MaxOccupants   = l.MaxOccupants,
                AllowPet       = l.AllowPet,
                AvailableFrom  = l.AvailableFrom,
                AmenityNames   = l.ListingAmenities
                                   .Select(la => la.Amenity?.Name ?? string.Empty)
                                   .Where(n => !string.IsNullOrEmpty(n))
                                   .ToList(),
                StatusName     = l.Status?.StatusName ?? string.Empty,
                IsVerified     = l.IsVerified,
                IsFeatured     = l.IsFeatured,
                ViewCount      = l.ViewCount,
                SaveCount      = l.SaveCount,
                AverageRating  = Math.Round(avgRating, 1),
                ReviewCount    = l.Reviews.Count,
                PackageInfo    = activePackage == null ? null : new PackageInfoDto
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
                CreatedAt = l.CreatedAt,
                ExpiredAt = l.ExpiredAt
            };
        }
    }
}
