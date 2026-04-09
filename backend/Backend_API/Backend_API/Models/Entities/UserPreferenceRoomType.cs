using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class UserPreferenceRoomType
{
    public long Id { get; set; }

    public long PrefId { get; set; }

    public int TypeId { get; set; }

    public virtual UserPreference Pref { get; set; } = null!;

    public virtual RoomType Type { get; set; } = null!;
}
