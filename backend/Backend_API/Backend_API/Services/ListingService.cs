using Backend_API.Data;
using Backend_API.Models.DTOs;
using Backend_API.Models.Entities;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Services;

public interface IListingService
{
    Task<PagedResult<ListingDto>> SearchAsync(ListingSearchQuery query);
    Task<ListingDetailDto?> GetDetailAsync(long listingId, long? userId);
    Task<Listing?> CreateAsync(long landlordId, CreateListingRequest req);
}

public class ListingService : IListingService
{
    private readonly AppDbContext _db;

    public ListingService(AppDbContext db) => _db = db;

    public async Task<PagedResult<ListingDto>> SearchAsync(ListingSearchQuery q)
    {
        var query = _db.Listings
            .Include(l => l.RoomType)
            .Include(l => l.Status)
            .Include(l => l.District)
            .Include(l => l.Province)
            .Include(l => l.Images)
            .Where(l => l.Status.StatusName == "active");

        // Filters
        if (!string.IsNullOrEmpty(q.Keyword))
            query = query.Where(l => l.Title.Contains(q.Keyword) || l.StreetAddress.Contains(q.Keyword));
        if (q.TypeId.HasValue)
            query = query.Where(l => l.TypeId == q.TypeId.Value);
        if (q.ProvinceId.HasValue)
            query = query.Where(l => l.ProvinceId == q.ProvinceId.Value);
        if (q.DistrictId.HasValue)
            query = query.Where(l => l.DistrictId == q.DistrictId.Value);
        if (q.MinPrice.HasValue)
            query = query.Where(l => l.Price >= q.MinPrice.Value);
        if (q.MaxPrice.HasValue)
            query = query.Where(l => l.Price <= q.MaxPrice.Value);
        if (q.MinArea.HasValue)
            query = query.Where(l => l.Area >= q.MinArea.Value);
        if (q.AllowPet.HasValue)
            query = query.Where(l => l.AllowPet == q.AllowPet.Value);

        // Sort
        query = q.SortBy switch
        {
            "price_asc" => query.OrderBy(l => l.Price),
            "price_desc" => query.OrderByDescending(l => l.Price),
            _ => query.OrderByDescending(l => l.IsFeatured).ThenByDescending(l => l.CreatedAt)
        };

        var total = await query.CountAsync();
        var items = await query
            .Skip((q.Page - 1) * q.PageSize)
            .Take(q.PageSize)
            .Select(l => new ListingDto(
                l.ListingId,
                l.Title,
                l.Price,
                l.Area,
                l.StreetAddress,
                l.District != null ? l.District.DistrictName : null,
                l.Province != null ? l.Province.ProvinceName : null,
                l.Latitude,
                l.Longitude,
                l.IsFeatured,
                l.IsVerified,
                l.AllowPet,
                l.Images.Where(i => i.IsCover).Select(i => i.ImageUrl).FirstOrDefault()
                    ?? l.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
                l.RoomType.TypeName,
                l.Status.StatusName,
                l.ViewCount,
                l.SaveCount,
                l.CreatedAt
            ))
            .ToListAsync();

        return new PagedResult<ListingDto>(items, total, q.Page, q.PageSize);
    }

    public async Task<ListingDetailDto?> GetDetailAsync(long listingId, long? userId)
    {
        var l = await _db.Listings
            .Include(x => x.RoomType)
            .Include(x => x.Status)
            .Include(x => x.Province)
            .Include(x => x.District)
            .Include(x => x.Ward)
            .Include(x => x.Landlord)
            .Include(x => x.Images.OrderBy(i => i.SortOrder))
            .Include(x => x.Amenities).ThenInclude(a => a.Amenity)
            .FirstOrDefaultAsync(x => x.ListingId == listingId);

        if (l == null) return null;

        // Tăng view count
        l.ViewCount++;
        await _db.SaveChangesAsync();

        return new ListingDetailDto(
            l.ListingId, l.Title, l.Description,
            l.Price, l.Area, l.Floor, l.TotalFloors, l.MaxOccupants,
            l.StreetAddress,
            l.Ward?.WardName, l.District?.DistrictName, l.Province?.ProvinceName,
            l.Latitude, l.Longitude,
            l.IsFeatured, l.IsVerified, l.IsNew, l.AllowPet,
            l.ElectricPrice, l.WaterPrice, l.InternetPrice, l.ParkingPrice,
            l.ViewCount, l.SaveCount,
            l.RoomType.TypeName, l.Status.StatusName,
            l.Landlord.FullName, l.Landlord.Phone, l.Landlord.AvatarUrl,
            l.Images.Select(i => i.ImageUrl).ToList(),
            l.Amenities.Select(a => a.Amenity.Name).ToList(),
            l.AvailableFrom, l.CreatedAt
        );
    }

    public async Task<Listing?> CreateAsync(long landlordId, CreateListingRequest req)
    {
        var pendingStatus = await _db.ListingStatuses.FirstAsync(s => s.StatusName == "pending");

        var listing = new Listing
        {
            LandlordId = landlordId,
            TypeId = req.TypeId,
            StatusId = pendingStatus.StatusId,
            Title = req.Title,
            Description = req.Description,
            Price = req.Price,
            Area = req.Area,
            Floor = req.Floor,
            TotalFloors = req.TotalFloors,
            MaxOccupants = req.MaxOccupants,
            ProvinceId = req.ProvinceId,
            DistrictId = req.DistrictId,
            WardId = req.WardId,
            StreetAddress = req.StreetAddress,
            Latitude = req.Latitude,
            Longitude = req.Longitude,
            AllowPet = req.AllowPet,
            ElectricPrice = req.ElectricPrice,
            WaterPrice = req.WaterPrice,
            InternetPrice = req.InternetPrice,
            ParkingPrice = req.ParkingPrice,
            AvailableFrom = req.AvailableFrom,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        _db.Listings.Add(listing);
        await _db.SaveChangesAsync();

        // Thêm ảnh
        if (req.ImageUrls.Count > 0)
        {
            var images = req.ImageUrls.Select((url, idx) => new ListingImage
            {
                ListingId = listing.ListingId,
                ImageUrl = url,
                IsCover = idx == 0,
                SortOrder = idx,
                CreatedAt = DateTime.UtcNow
            });
            _db.ListingImages.AddRange(images);
        }

        // Thêm tiện ích
        if (req.AmenityIds.Count > 0)
        {
            var amenities = req.AmenityIds.Select(aid => new ListingAmenity
            {
                ListingId = listing.ListingId,
                AmenityId = aid
            });
            _db.ListingAmenities.AddRange(amenities);
        }

        await _db.SaveChangesAsync();
        return listing;
    }
}
