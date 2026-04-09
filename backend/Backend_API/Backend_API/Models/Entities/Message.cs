using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class Message
{
    public long MessageId { get; set; }

    public long ConvId { get; set; }

    public long SenderId { get; set; }

    public string? Content { get; set; }

    public string? MsgType { get; set; }

    public string? FileUrl { get; set; }

    public string? StoragePath { get; set; }

    public bool? IsRead { get; set; }

    public bool? FcmSent { get; set; }

    public DateTime? FcmSentAt { get; set; }

    public DateTime? SentAt { get; set; }

    public virtual Conversation Conv { get; set; } = null!;

    public virtual User Sender { get; set; } = null!;
}
