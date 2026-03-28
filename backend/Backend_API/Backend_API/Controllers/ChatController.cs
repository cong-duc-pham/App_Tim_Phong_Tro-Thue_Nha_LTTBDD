using Backend_API.Data;
using Backend_API.Models.DTOs;
using Backend_API.Models.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Controllers;

[ApiController]
[Route("api")]
[Authorize]
public class ChatController : ControllerBase
{
    private readonly AppDbContext _db;
    public ChatController(AppDbContext db) => _db = db;

    /// <summary>Danh sách hội thoại của tôi</summary>
    [HttpGet("conversations")]
    public async Task<IActionResult> GetConversations()
    {
        var userId = GetUserId();
        var convs = await _db.Conversations
            .Include(c => c.Tenant)
            .Include(c => c.Landlord)
            .Include(c => c.Listing)
            .Where(c => c.TenantId == userId || c.LandlordId == userId)
            .OrderByDescending(c => c.LastMsgAt ?? c.CreatedAt)
            .Select(c => new
            {
                c.ConvId,
                ListingTitle = c.Listing != null ? c.Listing.Title : null,
                Tenant = new { c.Tenant.UserId, c.Tenant.FullName, c.Tenant.AvatarUrl },
                Landlord = new { c.Landlord.UserId, c.Landlord.FullName, c.Landlord.AvatarUrl },
                c.LastMsgAt,
                c.CreatedAt
            })
            .ToListAsync();

        return Ok(new ApiResponse<object>(true, null, convs));
    }

    /// <summary>Bắt đầu hội thoại về tin đăng (hoặc lấy hội thoại đã có)</summary>
    [HttpPost("conversations")]
    public async Task<IActionResult> StartConversation([FromBody] StartConvRequest req)
    {
        var userId = GetUserId();
        var listing = await _db.Listings.FindAsync(req.ListingId);
        if (listing == null) return NotFound();

        // Tránh tạo trùng
        var existing = await _db.Conversations
            .FirstOrDefaultAsync(c => c.ListingId == req.ListingId && c.TenantId == userId);

        if (existing != null)
            return Ok(new ApiResponse<object>(true, null, new { existing.ConvId }));

        var conv = new Conversation
        {
            ListingId = req.ListingId,
            TenantId = userId!.Value,
            LandlordId = listing.LandlordId,
            CreatedAt = DateTime.UtcNow
        };
        _db.Conversations.Add(conv);
        await _db.SaveChangesAsync();

        return StatusCode(201, new ApiResponse<object>(true, "Đã tạo hội thoại", new { conv.ConvId }));
    }

    /// <summary>Lấy tin nhắn trong hội thoại (phân trang)</summary>
    [HttpGet("conversations/{convId:long}/messages")]
    public async Task<IActionResult> GetMessages(long convId, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var userId = GetUserId();
        var conv = await _db.Conversations.FirstOrDefaultAsync(c => c.ConvId == convId
            && (c.TenantId == userId || c.LandlordId == userId));
        if (conv == null) return Forbid();

        var messages = await _db.Messages
            .Include(m => m.Sender)
            .Where(m => m.ConvId == convId)
            .OrderByDescending(m => m.SentAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(m => new
            {
                m.MessageId,
                m.Content,
                m.MsgType,
                m.FileUrl,
                m.IsRead,
                m.SentAt,
                Sender = new { m.Sender.UserId, m.Sender.FullName, m.Sender.AvatarUrl }
            })
            .ToListAsync();

        // Đánh dấu đã đọc
        await _db.Messages
            .Where(m => m.ConvId == convId && m.SenderId != userId && !m.IsRead)
            .ExecuteUpdateAsync(s => s.SetProperty(m => m.IsRead, true));

        return Ok(new ApiResponse<object>(true, null, messages));
    }

    /// <summary>Gửi tin nhắn</summary>
    [HttpPost("conversations/{convId:long}/messages")]
    public async Task<IActionResult> SendMessage(long convId, [FromBody] SendMessageRequest req)
    {
        var userId = GetUserId();
        var conv = await _db.Conversations.FirstOrDefaultAsync(c => c.ConvId == convId
            && (c.TenantId == userId || c.LandlordId == userId));
        if (conv == null) return Forbid();

        var msg = new Message
        {
            ConvId = convId,
            SenderId = userId!.Value,
            Content = req.Content,
            MsgType = req.MsgType ?? "text",
            FileUrl = req.FileUrl,
            SentAt = DateTime.UtcNow
        };
        _db.Messages.Add(msg);

        conv.LastMsgAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        return Ok(new ApiResponse<object>(true, null, new { msg.MessageId, msg.SentAt }));
    }

    private long? GetUserId()
    {
        var claim = User.FindFirst("userId")?.Value;
        return long.TryParse(claim, out var id) ? id : null;
    }
}

public record StartConvRequest(long ListingId);
public record SendMessageRequest(string? Content, string? MsgType, string? FileUrl);
