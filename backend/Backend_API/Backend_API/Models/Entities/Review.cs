namespace Backend_API.Models.Entities;

public class Review
{
    public long ReviewId { get; set; }
    public long ListingId { get; set; }
    public long ReviewerId { get; set; }
    public byte Rating { get; set; }
    public string? Comment { get; set; }
    public byte? RatingLocation { get; set; }
    public byte? RatingPrice { get; set; }
    public byte? RatingCleanness { get; set; }
    public byte? RatingSecurity { get; set; }
    public bool IsApproved { get; set; } = false;
    public string? LandlordReply { get; set; }
    public DateTime? RepliedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

    public Listing Listing { get; set; } = null!;
    public User Reviewer { get; set; } = null!;
    public ICollection<ReviewImage> Images { get; set; } = new List<ReviewImage>();
}

public class ReviewImage
{
    public long ImgId { get; set; }
    public long ReviewId { get; set; }
    public string ImageUrl { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Review Review { get; set; } = null!;
}
