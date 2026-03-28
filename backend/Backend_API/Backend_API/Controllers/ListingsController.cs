using System.Security.Claims;
using Backend_API.Data;
using Backend_API.Models.DTOs;
using Backend_API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers;

[ApiController]
[Route("api/listings")]
public class ListingsController : ControllerBase
{
    private readonly IListingService _listingService;
    private readonly AppDbContext _db;

    public ListingsController(IListingService listingService, AppDbContext db)
    {
        _listingService = listingService;
        _db = db;
    }

    /// <summary>Tìm kiếm / lọc tin đăng (public)</summary>
    [HttpGet]
    public async Task<IActionResult> Search([FromQuery] ListingSearchQuery query)
    {
        var result = await _listingService.SearchAsync(query);
        return Ok(new ApiResponse<PagedResult<ListingDto>>(true, null, result));
    }

    /// <summary>Xem chi tiết tin đăng (public)</summary>
    [HttpGet("{id:long}")]
    public async Task<IActionResult> GetDetail(long id)
    {
        var userId = GetUserId();
        var detail = await _listingService.GetDetailAsync(id, userId);
        if (detail == null) return NotFound(new ApiResponse<object>(false, "Không tìm thấy tin đăng", null));
        return Ok(new ApiResponse<ListingDetailDto>(true, null, detail));
    }

    /// <summary>Tạo tin đăng mới (chủ nhà)</summary>
    [HttpPost]
    [Authorize(Roles = "landlord")]
    public async Task<IActionResult> Create([FromBody] CreateListingRequest req)
    {
        var userId = GetUserId();
        if (userId == null) return Unauthorized();

        var listing = await _listingService.CreateAsync(userId.Value, req);
        return StatusCode(201, new ApiResponse<object>(true, "Đăng tin thành công, chờ admin duyệt", new { listing!.ListingId }));
    }

    /// <summary>Cập nhật tin đăng (chủ nhà sở hữu)</summary>
    [HttpPut("{id:long}")]
    [Authorize(Roles = "landlord")]
    public async Task<IActionResult> Update(long id, [FromBody] CreateListingRequest req)
    {
        var userId = GetUserId();
        var listing = await _db.Listings.FirstOrDefaultAsync(l => l.ListingId == id && l.LandlordId == userId);
        if (listing == null) return NotFound(new ApiResponse<object>(false, "Không tìm thấy tin đăng", null));

        listing.Title = req.Title;
        listing.Description = req.Description;
        listing.Price = req.Price;
        listing.Area = req.Area;
        listing.StreetAddress = req.StreetAddress;
        listing.AllowPet = req.AllowPet;
        listing.UpdatedAt = DateTime.UtcNow;

        await _db.SaveChangesAsync();
        return Ok(new ApiResponse<object>(true, "Cập nhật thành công", null));
    }

    /// <summary>Ẩn tin đăng (chủ nhà)</summary>
    [HttpDelete("{id:long}")]
    [Authorize(Roles = "landlord")]
    public async Task<IActionResult> Hide(long id)
    {
        var userId = GetUserId();
        var listing = await _db.Listings
            .Include(l => l.Status)
            .FirstOrDefaultAsync(l => l.ListingId == id && l.LandlordId == userId);
        if (listing == null) return NotFound(new ApiResponse<object>(false, "Không tìm thấy tin đăng", null));

        var hiddenStatus = await _db.ListingStatuses.FirstAsync(s => s.StatusName == "hidden");
        listing.StatusId = hiddenStatus.StatusId;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(true, "Đã ẩn tin đăng", null));
    }

    /// <summary>Lấy danh sách tiện ích (dùng khi tạo tin)</summary>
    [HttpGet("amenities")]
    public async Task<IActionResult> GetAmenities()
    {
        var amenities = await _db.Amenities
            .Where(a => a.IsActive)
            .OrderBy(a => a.Category)
            .Select(a => new { a.AmenityId, a.Name, a.Category, a.IconUrl })
            .ToListAsync();
        return Ok(new ApiResponse<object>(true, null, amenities));
    }

    /// <summary>Lấy danh sách loại phòng</summary>
    [HttpGet("room-types")]
    public async Task<IActionResult> GetRoomTypes()
    {
        var types = await _db.RoomTypes
            .Where(t => t.IsActive)
            .OrderBy(t => t.SortOrder)
            .Select(t => new { t.TypeId, t.TypeName, t.IconUrl })
            .ToListAsync();
        return Ok(new ApiResponse<object>(true, null, types));
    }

    private long? GetUserId()
    {
        var claim = User.FindFirst("userId")?.Value;
        return long.TryParse(claim, out var id) ? id : null;
    }
}
