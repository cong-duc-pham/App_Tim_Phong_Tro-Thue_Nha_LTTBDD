using System;
using System.Collections.Generic;

namespace Backend_API.Models.Entities;

public partial class User
{
    public long UserId { get; set; }

    public string FullName { get; set; } = null!;

    public string? Email { get; set; }

    public string? Phone { get; set; }

    public string? PasswordHash { get; set; }

    public string? AvatarUrl { get; set; }

    public DateOnly? DateOfBirth { get; set; }

    public byte? Gender { get; set; }

    public int RoleId { get; set; }

    public bool? IsVerified { get; set; }

    public bool? IsActive { get; set; }

    public DateTime? LastLogin { get; set; }

    public string? FirebaseUid { get; set; }

    public string? FirebaseProvider { get; set; }

    public string? AvatarSource { get; set; }

    public DateTime? CreatedAt { get; set; }

    public DateTime? UpdatedAt { get; set; }

    public virtual ICollection<AdminLog> AdminLogs { get; set; } = new List<AdminLog>();

    public virtual ICollection<Conversation> ConversationLandlords { get; set; } = new List<Conversation>();

    public virtual ICollection<Conversation> ConversationTenants { get; set; } = new List<Conversation>();

    public virtual ICollection<Favorite> Favorites { get; set; } = new List<Favorite>();

    public virtual ICollection<CloudinaryFile> CloudinaryFiles { get; set; } = new List<CloudinaryFile>();

    public virtual ICollection<FirebaseTokenLog> FirebaseTokenLogs { get; set; } = new List<FirebaseTokenLog>();

    public virtual ICollection<Invoice> Invoices { get; set; } = new List<Invoice>();

    public virtual ICollection<Listing> Listings { get; set; } = new List<Listing>();

    public virtual ICollection<Message> Messages { get; set; } = new List<Message>();

    public virtual ICollection<Notification> Notifications { get; set; } = new List<Notification>();

    public virtual ICollection<OtpCode> OtpCodes { get; set; } = new List<OtpCode>();

    public virtual ICollection<Report> ReportReporters { get; set; } = new List<Report>();

    public virtual ICollection<Report> ReportResolvedByNavigations { get; set; } = new List<Report>();

    public virtual ICollection<Report> ReportUsers { get; set; } = new List<Report>();

    public virtual ICollection<Review> Reviews { get; set; } = new List<Review>();

    public virtual ICollection<ReviewLike> ReviewLikes { get; set; } = new List<ReviewLike>();

    public virtual Role Role { get; set; } = null!;

    public virtual ICollection<SearchHistory> SearchHistories { get; set; } = new List<SearchHistory>();

    public virtual ICollection<SocialAuthProvider> SocialAuthProviders { get; set; } = new List<SocialAuthProvider>();

    public virtual ICollection<UserDevice> UserDevices { get; set; } = new List<UserDevice>();

    public virtual UserPreference? UserPreference { get; set; }

    public virtual ICollection<ViewHistory> ViewHistories { get; set; } = new List<ViewHistory>();
}
