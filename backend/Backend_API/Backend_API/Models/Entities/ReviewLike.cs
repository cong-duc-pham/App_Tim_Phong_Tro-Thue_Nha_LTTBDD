using System;

namespace Backend_API.Models.Entities;

public partial class ReviewLike
{
    public long ReviewLikeId { get; set; }

    public long ReviewId { get; set; }

    public long UserId { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Review Review { get; set; } = null!;

    public virtual User User { get; set; } = null!;
}
