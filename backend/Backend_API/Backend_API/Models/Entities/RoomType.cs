using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class RoomType
{
    public int TypeId { get; set; }

    public string TypeName { get; set; } = null!;

    public string? IconUrl { get; set; }

    public int? SortOrder { get; set; }

    public bool? IsActive { get; set; }

    public virtual ICollection<Listing> Listings { get; set; } = new List<Listing>();

    public virtual ICollection<UserPreferenceRoomType> UserPreferenceRoomTypes { get; set; } = new List<UserPreferenceRoomType>();
}
