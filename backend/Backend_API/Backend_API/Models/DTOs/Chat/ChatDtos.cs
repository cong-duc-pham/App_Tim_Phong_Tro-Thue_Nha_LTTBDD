using System;
using System.Collections.Generic;

namespace Backend_API.Models.DTOs.Chat
{
    public class MessageDto
    {
        public long MessageId { get; set; }
        public long ConvId { get; set; }
        public long SenderId { get; set; }
        public string? Content { get; set; }
        public string? MsgType { get; set; }
        public string? FileUrl { get; set; }
        public bool IsRead { get; set; }
        public DateTime? SentAt { get; set; }
    }

    public class ConversationDto
    {
        public long ConvId { get; set; }
        public long? ListingId { get; set; }
        public string? ListingTitle { get; set; }
        public string? ListingImage { get; set; }
        public string? ListingStatusName { get; set; }
        public bool CanConfirmRental { get; set; }
        public long TenantId { get; set; }
        public long LandlordId { get; set; }

        public string? LastMessage { get; set; }
        public DateTime? LastMsgAt { get; set; }

        public long OtherUserId { get; set; }
        public string OtherUserName { get; set; } = null!;
        public string? OtherUserAvatar { get; set; }
        public string? OtherUserPhone { get; set; }

        public int UnreadCount { get; set; }
    }

    public class CreateConversationDto
    {
        public long ListingId { get; set; }
        public long LandlordId { get; set; }
    }

    public class SendMessageDto
    {
        public long ConvId { get; set; }
        public string Content { get; set; } = null!;
        public string MsgType { get; set; } = "text"; // text, image, file
        public string? FileUrl { get; set; }
    }
}
