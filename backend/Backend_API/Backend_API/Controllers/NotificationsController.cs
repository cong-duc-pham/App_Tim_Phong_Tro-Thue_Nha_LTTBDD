using Backend_API.Data;
using Backend_API.Models.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers;

[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController : ControllerBase
{
    private readonly AppDbContext _db;
    public NotificationsController(AppDbContext db) => _db = db;

    /// <summary>Lấy thông báo (20 mới nhất, phân trang)</summary>
    [HttpGet]
    public async Task<IActionResult> GetNotifications([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var userId = GetUserId();
        var notifs = await _db.Notifications
            .Where(n => n.UserId == userId)
            .OrderByDescending(n => n.SentAt)
            .Skip((page - 1) * pageSize).Take(pageSize)
            .Select(n => new { n.NotifId, n.Title, n.Body, n.NotifType, n.RefId, n.RefType, n.IsRead, n.SentAt })
            .ToListAsync();

        var unreadCount = await _db.Notifications.CountAsync(n => n.UserId == userId && !n.IsRead);

        return Ok(new ApiResponse<object>(true, null, new { UnreadCount = unreadCount, Notifications = notifs }));
    }

    /// <summary>Đánh dấu thông báo đã đọc</summary>
    [HttpPut("{id:long}/read")]
    public async Task<IActionResult> MarkRead(long id)
    {
        var userId = GetUserId();
        await _db.Notifications
            .Where(n => n.NotifId == id && n.UserId == userId)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));
        return Ok(new ApiResponse<object>(true, "Đã đánh dấu đọc", null));
    }

    /// <summary>Đọc tất cả</summary>
    [HttpPut("read-all")]
    public async Task<IActionResult> MarkAllRead()
    {
        var userId = GetUserId();
        await _db.Notifications
            .Where(n => n.UserId == userId && !n.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(n => n.IsRead, true));
        return Ok(new ApiResponse<object>(true, "Đã đọc tất cả", null));
    }

    private long? GetUserId()
    {
        var claim = User.FindFirst("userId")?.Value;
        return long.TryParse(claim, out var id) ? id : null;
    }
}
