using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class VwUserFirebaseInfo
{
    public long UserId { get; set; }

    public string FullName { get; set; } = null!;

    public string? Email { get; set; }

    public string? Phone { get; set; }

    public string? FirebaseUid { get; set; }

    public string? FirebaseProvider { get; set; }

    public string? AvatarUrl { get; set; }

    public string? AvatarSource { get; set; }

    public bool? IsVerified { get; set; }

    public bool? IsActive { get; set; }

    public string RoleName { get; set; } = null!;

    public int? ActiveDevices { get; set; }

    public int UsesFirebase { get; set; }

    public string AuthMethod { get; set; } = null!;
}
