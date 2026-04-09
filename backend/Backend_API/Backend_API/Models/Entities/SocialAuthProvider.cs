using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class SocialAuthProvider
{
    public long ProviderId { get; set; }

    public long UserId { get; set; }

    public string Provider { get; set; } = null!;

    public string ProviderUid { get; set; } = null!;

    public string? FirebaseUid { get; set; }

    public string? AccessToken { get; set; }

    public string? RefreshToken { get; set; }

    public DateTime? TokenExpiresAt { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual User User { get; set; } = null!;
}
