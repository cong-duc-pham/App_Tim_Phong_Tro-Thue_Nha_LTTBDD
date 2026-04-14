using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class ListingImage
{
    public long ImageId { get; set; }

    public long ListingId { get; set; }

    public string CloudinaryUrl { get; set; } = null!;

    public string? CloudinaryPublicId { get; set; }

    public string? SecureUrl { get; set; }

    public int? Width { get; set; }

    public int? Height { get; set; }

    public string? Format { get; set; }

    public bool? IsCover { get; set; }

    public int? SortOrder { get; set; }

    public DateTime? CreatedAt { get; set; }

    public virtual Listing Listing { get; set; } = null!;
}
