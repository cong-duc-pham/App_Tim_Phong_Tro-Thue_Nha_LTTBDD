using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities
{
    public partial class Review
    {
        public long ReviewId { get; set; }

        public long ListingId { get; set; }

        public long ReviewerId { get; set; }

        public byte? Rating { get; set; }

        public string? Comment { get; set; }

        public byte? RatingLocation { get; set; }

        public byte? RatingPrice { get; set; }

        public byte? RatingCleanness { get; set; }

        public byte? RatingSecurity { get; set; }

        public bool? IsApproved { get; set; }

        public string Type { get; set; } = "review";

        public string Status { get; set; } = "approved";

        public int ReportCount { get; set; } = 0;

        public bool IsDeleted { get; set; } = false;

        public string? LandlordReply { get; set; }

        public DateTime? RepliedAt { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public virtual Listing Listing { get; set; } = null!;

        public virtual ICollection<ReviewImage> ReviewImages { get; set; } = new List<ReviewImage>();

        public virtual ICollection<ReviewLike> ReviewLikes { get; set; } = new List<ReviewLike>();

        public virtual User Reviewer { get; set; } = null!;
    }
}
