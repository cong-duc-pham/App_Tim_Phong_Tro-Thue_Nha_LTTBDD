using Backend_API.Data;
using Backend_API.Models.DTOs;
using Backend_API.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers;

[ApiController]
[Route("api/favorites")]
[Authorize]
public class FavoritesController : ControllerBase
{
    private readonly AppDbContext _db;
    public FavoritesController(AppDbContext db) => _db = db;

    /// <summary>Danh sách tin đăng đã lưu</summary>
    [HttpGet]
    public async Task<IActionResult> GetFavorites()
    {
        var userId = GetUserId();
        var favorites = await _db.Favorites
            .Include(f => f.Listing).ThenInclude(l => l.Images)
            .Include(f => f.Listing).ThenInclude(l => l.District)
            .Include(f => f.Listing).ThenInclude(l => l.Province)
            .Include(f => f.Listing).ThenInclude(l => l.RoomType)
            .Include(f => f.Listing).ThenInclude(l => l.Status)
            .Where(f => f.UserId == userId)
            .OrderByDescending(f => f.CreatedAt)
            .Select(f => new ListingDto(
                f.Listing.ListingId, f.Listing.Title, f.Listing.Price, f.Listing.Area,
                f.Listing.StreetAddress,
                f.Listing.District != null ? f.Listing.District.DistrictName : null,
                f.Listing.Province != null ? f.Listing.Province.ProvinceName : null,
                f.Listing.Latitude, f.Listing.Longitude,
                f.Listing.IsFeatured, f.Listing.IsVerified, f.Listing.AllowPet,
                f.Listing.Images.Where(i => i.IsCover).Select(i => i.ImageUrl).FirstOrDefault()
                    ?? f.Listing.Images.OrderBy(i => i.SortOrder).Select(i => i.ImageUrl).FirstOrDefault(),
                f.Listing.RoomType.TypeName, f.Listing.Status.StatusName,
                f.Listing.ViewCount, f.Listing.SaveCount, f.Listing.CreatedAt
            ))
            .ToListAsync();

        return Ok(new ApiResponse<List<ListingDto>>(true, null, favorites));
    }

    /// <summary>Lưu tin đăng vào yêu thích</summary>
    [HttpPost("{listingId:long}")]
    public async Task<IActionResult> Add(long listingId)
    {
        var userId = GetUserId();
        var exists = await _db.Favorites.AnyAsync(f => f.UserId == userId && f.ListingId == listingId);
        if (exists) return Conflict(new ApiResponse<object>(false, "Đã lưu trước đó", null));

        _db.Favorites.Add(new Favorite { UserId = userId!.Value, ListingId = listingId });

        // Tăng save_count
        var listing = await _db.Listings.FindAsync(listingId);
        if (listing != null) listing.SaveCount++;

        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(true, "Đã lưu vào danh sách yêu thích", null));
    }

    /// <summary>Xóa khỏi yêu thích</summary>
    [HttpDelete("{listingId:long}")]
    public async Task<IActionResult> Remove(long listingId)
    {
        var userId = GetUserId();
        var fav = await _db.Favorites.FirstOrDefaultAsync(f => f.UserId == userId && f.ListingId == listingId);
        if (fav == null) return NotFound(new ApiResponse<object>(false, "Không tìm thấy", null));

        _db.Favorites.Remove(fav);

        var listing = await _db.Listings.FindAsync(listingId);
        if (listing != null && listing.SaveCount > 0) listing.SaveCount--;

        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(true, "Đã xóa khỏi yêu thích", null));
    }

    private long? GetUserId()
    {
        var claim = User.FindFirst("userId")?.Value;
        return long.TryParse(claim, out var id) ? id : null;
    }
}
