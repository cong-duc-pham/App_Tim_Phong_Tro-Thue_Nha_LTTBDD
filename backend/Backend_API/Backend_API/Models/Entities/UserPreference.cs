using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class UserPreference
{
    public long PrefId { get; set; }

    public long UserId { get; set; }

    public string? PreferredArea { get; set; }

    public decimal? MinPrice { get; set; }

    public decimal? MaxPrice { get; set; }

    public bool? AllowPet { get; set; }

    public double? Latitude { get; set; }

    public double? Longitude { get; set; }

    public int? SearchRadiusKm { get; set; }

    public bool? OnboardingDone { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual User User { get; set; } = null!;

    public virtual ICollection<UserPreferenceAmenity> UserPreferenceAmenities { get; set; } = new List<UserPreferenceAmenity>();

    public virtual ICollection<UserPreferenceRoomType> UserPreferenceRoomTypes { get; set; } = new List<UserPreferenceRoomType>();
}
