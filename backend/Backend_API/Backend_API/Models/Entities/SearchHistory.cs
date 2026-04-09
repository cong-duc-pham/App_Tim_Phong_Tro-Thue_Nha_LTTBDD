using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class SearchHistory
{
    public long SearchId { get; set; }

    public long UserId { get; set; }

    public string Keyword { get; set; } = null!;

    public string? FilterJson { get; set; }

    public int? ResultCount { get; set; }

    public DateTime? SearchedAt { get; set; }

    public virtual User User { get; set; } = null!;
}
