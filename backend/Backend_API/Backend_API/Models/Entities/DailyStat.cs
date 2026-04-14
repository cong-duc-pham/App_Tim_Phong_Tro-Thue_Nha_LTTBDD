using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class DailyStat
{
    public long StatId { get; set; }

    public DateOnly StatDate { get; set; }

    public int? NewUsers { get; set; }

    public int? NewUsersFirebase { get; set; }

    public int? NewListings { get; set; }

    public decimal? TotalRevenue { get; set; }

    public int? TotalSearches { get; set; }

    public int? ActiveListings { get; set; }

    public int? FcmSentCount { get; set; }

    public int? FcmFailedCount { get; set; }

    public int? CloudinaryUploadCount { get; set; }

    public decimal? CloudinaryUploadMb { get; set; }

    public int? CloudinaryDeleteCount { get; set; }

    public DateTime? CreatedAt { get; set; }
}
