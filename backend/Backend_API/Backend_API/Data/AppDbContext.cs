using Microsoft.EntityFrameworkCore;
using Backend_API.Models.Entities;

namespace Backend_API.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    // Users & Auth
    public DbSet<Role> Roles => Set<Role>();
    public DbSet<User> Users => Set<User>();
    public DbSet<OtpCode> OtpCodes => Set<OtpCode>();
    public DbSet<UserPreference> UserPreferences => Set<UserPreference>();

    // Categories
    public DbSet<RoomType> RoomTypes => Set<RoomType>();
    public DbSet<Amenity> Amenities => Set<Amenity>();

    // Geography
    public DbSet<Province> Provinces => Set<Province>();
    public DbSet<District> Districts => Set<District>();
    public DbSet<Ward> Wards => Set<Ward>();

    // Listings
    public DbSet<ListingStatus> ListingStatuses => Set<ListingStatus>();
    public DbSet<Listing> Listings => Set<Listing>();
    public DbSet<ListingImage> ListingImages => Set<ListingImage>();
    public DbSet<ListingAmenity> ListingAmenities => Set<ListingAmenity>();
    public DbSet<Favorite> Favorites => Set<Favorite>();

    // Chat
    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<Message> Messages => Set<Message>();

    // Other
    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<Review> Reviews => Set<Review>();
    public DbSet<ReviewImage> ReviewImages => Set<ReviewImage>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        base.OnModelCreating(model);

        // ── Table name mapping (snake_case SQL ↔ PascalCase C#)
        model.Entity<Role>().ToTable("Roles").HasKey(r => r.RoleId);
        model.Entity<User>().ToTable("Users").HasKey(u => u.UserId);
        model.Entity<OtpCode>().ToTable("OtpCodes").HasKey(o => o.OtpId);
        model.Entity<UserPreference>().ToTable("UserPreferences").HasKey(p => p.PrefId);

        model.Entity<RoomType>().ToTable("RoomTypes").HasKey(r => r.TypeId);
        model.Entity<Amenity>().ToTable("Amenities").HasKey(a => a.AmenityId);

        model.Entity<Province>().ToTable("Provinces").HasKey(p => p.ProvinceId);
        model.Entity<District>().ToTable("Districts").HasKey(d => d.DistrictId);
        model.Entity<Ward>().ToTable("Wards").HasKey(w => w.WardId);

        model.Entity<ListingStatus>().ToTable("ListingStatus").HasKey(s => s.StatusId);
        model.Entity<Listing>().ToTable("Listings").HasKey(l => l.ListingId);
        model.Entity<ListingImage>().ToTable("ListingImages").HasKey(i => i.ImageId);
        model.Entity<ListingAmenity>().ToTable("ListingAmenities").HasKey(a => a.Id);
        model.Entity<Favorite>().ToTable("Favorites").HasKey(f => f.FavoriteId);

        model.Entity<Conversation>().ToTable("Conversations").HasKey(c => c.ConvId);
        model.Entity<Message>().ToTable("Messages").HasKey(m => m.MessageId);
        model.Entity<Notification>().ToTable("Notifications").HasKey(n => n.NotifId);
        model.Entity<Review>().ToTable("Reviews").HasKey(r => r.ReviewId);
        model.Entity<ReviewImage>().ToTable("ReviewImages").HasKey(i => i.ImgId);

        // ── Column name mapping (EF tự map PascalCase → snake_case cần khai báo thủ công)
        model.Entity<Role>().Property(r => r.RoleId).HasColumnName("role_id");
        model.Entity<Role>().Property(r => r.RoleName).HasColumnName("role_name");
        model.Entity<Role>().Property(r => r.CreatedAt).HasColumnName("created_at");

        model.Entity<User>().Property(u => u.UserId).HasColumnName("user_id");
        model.Entity<User>().Property(u => u.FullName).HasColumnName("full_name");
        model.Entity<User>().Property(u => u.PasswordHash).HasColumnName("password_hash");
        model.Entity<User>().Property(u => u.AvatarUrl).HasColumnName("avatar_url");
        model.Entity<User>().Property(u => u.DateOfBirth).HasColumnName("date_of_birth");
        model.Entity<User>().Property(u => u.RoleId).HasColumnName("role_id");
        model.Entity<User>().Property(u => u.IsVerified).HasColumnName("is_verified");
        model.Entity<User>().Property(u => u.IsActive).HasColumnName("is_active");
        model.Entity<User>().Property(u => u.LastLogin).HasColumnName("last_login");
        model.Entity<User>().Property(u => u.CreatedAt).HasColumnName("created_at");
        model.Entity<User>().Property(u => u.UpdatedAt).HasColumnName("updated_at");

        model.Entity<OtpCode>().Property(o => o.OtpId).HasColumnName("otp_id");
        model.Entity<OtpCode>().Property(o => o.UserId).HasColumnName("user_id");
        model.Entity<OtpCode>().Property(o => o.OtpType).HasColumnName("otp_type");
        model.Entity<OtpCode>().Property(o => o.IsUsed).HasColumnName("is_used");
        model.Entity<OtpCode>().Property(o => o.ExpiresAt).HasColumnName("expires_at");
        model.Entity<OtpCode>().Property(o => o.CreatedAt).HasColumnName("created_at");

        model.Entity<RoomType>().Property(r => r.TypeId).HasColumnName("type_id");
        model.Entity<RoomType>().Property(r => r.TypeName).HasColumnName("type_name");
        model.Entity<RoomType>().Property(r => r.IconUrl).HasColumnName("icon_url");
        model.Entity<RoomType>().Property(r => r.SortOrder).HasColumnName("sort_order");
        model.Entity<RoomType>().Property(r => r.IsActive).HasColumnName("is_active");

        model.Entity<Amenity>().Property(a => a.AmenityId).HasColumnName("amenity_id");
        model.Entity<Amenity>().Property(a => a.IconUrl).HasColumnName("icon_url");
        model.Entity<Amenity>().Property(a => a.IsActive).HasColumnName("is_active");

        model.Entity<UserPreference>().Property(p => p.PrefId).HasColumnName("pref_id");
        model.Entity<UserPreference>().Property(p => p.UserId).HasColumnName("user_id");
        model.Entity<UserPreference>().Property(p => p.PreferredArea).HasColumnName("preferred_area");
        model.Entity<UserPreference>().Property(p => p.MinPrice).HasColumnName("min_price");
        model.Entity<UserPreference>().Property(p => p.MaxPrice).HasColumnName("max_price");
        model.Entity<UserPreference>().Property(p => p.AllowPet).HasColumnName("allow_pet");
        model.Entity<UserPreference>().Property(p => p.SearchRadiusKm).HasColumnName("search_radius_km");
        model.Entity<UserPreference>().Property(p => p.OnboardingDone).HasColumnName("onboarding_done");
        model.Entity<UserPreference>().Property(p => p.CreatedAt).HasColumnName("created_at");
        model.Entity<UserPreference>().Property(p => p.UpdatedAt).HasColumnName("updated_at");

        model.Entity<Province>().Property(p => p.ProvinceId).HasColumnName("province_id");
        model.Entity<Province>().Property(p => p.ProvinceName).HasColumnName("province_name");
        model.Entity<Province>().Property(p => p.ProvinceCode).HasColumnName("province_code");

        model.Entity<District>().Property(d => d.DistrictId).HasColumnName("district_id");
        model.Entity<District>().Property(d => d.ProvinceId).HasColumnName("province_id");
        model.Entity<District>().Property(d => d.DistrictName).HasColumnName("district_name");
        model.Entity<District>().Property(d => d.DistrictCode).HasColumnName("district_code");

        model.Entity<Ward>().Property(w => w.WardId).HasColumnName("ward_id");
        model.Entity<Ward>().Property(w => w.DistrictId).HasColumnName("district_id");
        model.Entity<Ward>().Property(w => w.WardName).HasColumnName("ward_name");
        model.Entity<Ward>().Property(w => w.WardCode).HasColumnName("ward_code");

        model.Entity<ListingStatus>().Property(s => s.StatusId).HasColumnName("status_id");
        model.Entity<ListingStatus>().Property(s => s.StatusName).HasColumnName("status_name");

        model.Entity<Listing>().Property(l => l.ListingId).HasColumnName("listing_id");
        model.Entity<Listing>().Property(l => l.LandlordId).HasColumnName("landlord_id");
        model.Entity<Listing>().Property(l => l.TypeId).HasColumnName("type_id");
        model.Entity<Listing>().Property(l => l.StatusId).HasColumnName("status_id");
        model.Entity<Listing>().Property(l => l.MaxOccupants).HasColumnName("max_occupants");
        model.Entity<Listing>().Property(l => l.ProvinceId).HasColumnName("province_id");
        model.Entity<Listing>().Property(l => l.DistrictId).HasColumnName("district_id");
        model.Entity<Listing>().Property(l => l.WardId).HasColumnName("ward_id");
        model.Entity<Listing>().Property(l => l.StreetAddress).HasColumnName("street_address");
        model.Entity<Listing>().Property(l => l.IsVerified).HasColumnName("is_verified");
        model.Entity<Listing>().Property(l => l.IsFeatured).HasColumnName("is_featured");
        model.Entity<Listing>().Property(l => l.IsNew).HasColumnName("is_new");
        model.Entity<Listing>().Property(l => l.AllowPet).HasColumnName("allow_pet");
        model.Entity<Listing>().Property(l => l.ElectricPrice).HasColumnName("electric_price");
        model.Entity<Listing>().Property(l => l.WaterPrice).HasColumnName("water_price");
        model.Entity<Listing>().Property(l => l.InternetPrice).HasColumnName("internet_price");
        model.Entity<Listing>().Property(l => l.ParkingPrice).HasColumnName("parking_price");
        model.Entity<Listing>().Property(l => l.ViewCount).HasColumnName("view_count");
        model.Entity<Listing>().Property(l => l.SaveCount).HasColumnName("save_count");
        model.Entity<Listing>().Property(l => l.AvailableFrom).HasColumnName("available_from");
        model.Entity<Listing>().Property(l => l.ExpiredAt).HasColumnName("expired_at");
        model.Entity<Listing>().Property(l => l.CreatedAt).HasColumnName("created_at");
        model.Entity<Listing>().Property(l => l.UpdatedAt).HasColumnName("updated_at");

        model.Entity<ListingImage>().Property(i => i.ImageId).HasColumnName("image_id");
        model.Entity<ListingImage>().Property(i => i.ListingId).HasColumnName("listing_id");
        model.Entity<ListingImage>().Property(i => i.ImageUrl).HasColumnName("image_url");
        model.Entity<ListingImage>().Property(i => i.IsCover).HasColumnName("is_cover");
        model.Entity<ListingImage>().Property(i => i.SortOrder).HasColumnName("sort_order");
        model.Entity<ListingImage>().Property(i => i.CreatedAt).HasColumnName("created_at");

        model.Entity<ListingAmenity>().Property(a => a.ListingId).HasColumnName("listing_id");
        model.Entity<ListingAmenity>().Property(a => a.AmenityId).HasColumnName("amenity_id");

        model.Entity<Favorite>().Property(f => f.FavoriteId).HasColumnName("favorite_id");
        model.Entity<Favorite>().Property(f => f.UserId).HasColumnName("user_id");
        model.Entity<Favorite>().Property(f => f.ListingId).HasColumnName("listing_id");
        model.Entity<Favorite>().Property(f => f.CreatedAt).HasColumnName("created_at");
        model.Entity<Favorite>().HasIndex(f => new { f.UserId, f.ListingId }).IsUnique();

        model.Entity<Conversation>().Property(c => c.ConvId).HasColumnName("conv_id");
        model.Entity<Conversation>().Property(c => c.ListingId).HasColumnName("listing_id");
        model.Entity<Conversation>().Property(c => c.TenantId).HasColumnName("tenant_id");
        model.Entity<Conversation>().Property(c => c.LandlordId).HasColumnName("landlord_id");
        model.Entity<Conversation>().Property(c => c.LastMsgAt).HasColumnName("last_msg_at");
        model.Entity<Conversation>().Property(c => c.CreatedAt).HasColumnName("created_at");
        // Conversation có 2 FK đến Users nên phải cấu hình thủ công
        model.Entity<Conversation>()
            .HasOne(c => c.Tenant).WithMany().HasForeignKey(c => c.TenantId).OnDelete(DeleteBehavior.Restrict);
        model.Entity<Conversation>()
            .HasOne(c => c.Landlord).WithMany().HasForeignKey(c => c.LandlordId).OnDelete(DeleteBehavior.Restrict);

        model.Entity<Message>().Property(m => m.MessageId).HasColumnName("message_id");
        model.Entity<Message>().Property(m => m.ConvId).HasColumnName("conv_id");
        model.Entity<Message>().Property(m => m.SenderId).HasColumnName("sender_id");
        model.Entity<Message>().Property(m => m.MsgType).HasColumnName("msg_type");
        model.Entity<Message>().Property(m => m.FileUrl).HasColumnName("file_url");
        model.Entity<Message>().Property(m => m.IsRead).HasColumnName("is_read");
        model.Entity<Message>().Property(m => m.SentAt).HasColumnName("sent_at");
        model.Entity<Message>()
            .HasOne(m => m.Sender).WithMany().HasForeignKey(m => m.SenderId).OnDelete(DeleteBehavior.Restrict);

        model.Entity<Notification>().Property(n => n.NotifId).HasColumnName("notif_id");
        model.Entity<Notification>().Property(n => n.UserId).HasColumnName("user_id");
        model.Entity<Notification>().Property(n => n.NotifType).HasColumnName("notif_type");
        model.Entity<Notification>().Property(n => n.RefId).HasColumnName("ref_id");
        model.Entity<Notification>().Property(n => n.RefType).HasColumnName("ref_type");
        model.Entity<Notification>().Property(n => n.IsRead).HasColumnName("is_read");
        model.Entity<Notification>().Property(n => n.SentAt).HasColumnName("sent_at");

        model.Entity<Review>().Property(r => r.ReviewId).HasColumnName("review_id");
        model.Entity<Review>().Property(r => r.ListingId).HasColumnName("listing_id");
        model.Entity<Review>().Property(r => r.ReviewerId).HasColumnName("reviewer_id");
        model.Entity<Review>().Property(r => r.RatingLocation).HasColumnName("rating_location");
        model.Entity<Review>().Property(r => r.RatingPrice).HasColumnName("rating_price");
        model.Entity<Review>().Property(r => r.RatingCleanness).HasColumnName("rating_cleanness");
        model.Entity<Review>().Property(r => r.RatingSecurity).HasColumnName("rating_security");
        model.Entity<Review>().Property(r => r.IsApproved).HasColumnName("is_approved");
        model.Entity<Review>().Property(r => r.LandlordReply).HasColumnName("landlord_reply");
        model.Entity<Review>().Property(r => r.RepliedAt).HasColumnName("replied_at");
        model.Entity<Review>().Property(r => r.CreatedAt).HasColumnName("created_at");
        model.Entity<Review>().Property(r => r.UpdatedAt).HasColumnName("updated_at");
        model.Entity<Review>()
            .HasOne(r => r.Reviewer).WithMany().HasForeignKey(r => r.ReviewerId).OnDelete(DeleteBehavior.Restrict);
        model.Entity<Review>().HasIndex(r => new { r.ListingId, r.ReviewerId }).IsUnique();

        model.Entity<ReviewImage>().Property(i => i.ImgId).HasColumnName("img_id");
        model.Entity<ReviewImage>().Property(i => i.ReviewId).HasColumnName("review_id");
        model.Entity<ReviewImage>().Property(i => i.ImageUrl).HasColumnName("image_url");
        model.Entity<ReviewImage>().Property(i => i.CreatedAt).HasColumnName("created_at");
    }
}
