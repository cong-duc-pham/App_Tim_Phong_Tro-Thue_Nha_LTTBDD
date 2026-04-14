using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ReviewImage
{
    public long ImgId { get; set; }

    public long ReviewId { get; set; }

    public string ImageUrl { get; set; } = null!;

    public string? CloudinaryPublicId { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Review Review { get; set; } = null!;
}
