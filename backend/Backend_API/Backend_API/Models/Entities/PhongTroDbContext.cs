using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;

namespace Backend_API.Models.Entities;

public partial class PhongTroDbContext : DbContext
{
    public PhongTroDbContext()
    {
    }

    public PhongTroDbContext(DbContextOptions<PhongTroDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<AdminLog> AdminLogs { get; set; }

    public virtual DbSet<Amenity> Amenities { get; set; }

    public virtual DbSet<Banner> Banners { get; set; }

    public virtual DbSet<Conversation> Conversations { get; set; }

    public virtual DbSet<DailyStat> DailyStats { get; set; }

    public virtual DbSet<District> Districts { get; set; }

    public virtual DbSet<Favorite> Favorites { get; set; }

    public virtual DbSet<CloudinaryFile> CloudinaryFiles { get; set; }

    public virtual DbSet<FirebaseTokenLog> FirebaseTokenLogs { get; set; }

    public virtual DbSet<Invoice> Invoices { get; set; }

    public virtual DbSet<Listing> Listings { get; set; }

    public virtual DbSet<ListingAmenity> ListingAmenities { get; set; }

    public virtual DbSet<ListingImage> ListingImages { get; set; }

    public virtual DbSet<ListingPostPackage> ListingPostPackages { get; set; }

    public virtual DbSet<ListingPriceHistory> ListingPriceHistories { get; set; }

    public virtual DbSet<ListingStatus> ListingStatuses { get; set; }

    public virtual DbSet<ListingVideo> ListingVideos { get; set; }

    public virtual DbSet<Message> Messages { get; set; }

    public virtual DbSet<Notification> Notifications { get; set; }

    public virtual DbSet<OtpCode> OtpCodes { get; set; }

    public virtual DbSet<Payment> Payments { get; set; }

    public virtual DbSet<PaymentMethod> PaymentMethods { get; set; }

    public virtual DbSet<PaymentStatus> PaymentStatuses { get; set; }

    public virtual DbSet<PostPackage> PostPackages { get; set; }

    public virtual DbSet<Province> Provinces { get; set; }

    public virtual DbSet<Report> Reports { get; set; }

    public virtual DbSet<Review> Reviews { get; set; }

    public virtual DbSet<ReviewImage> ReviewImages { get; set; }

    public virtual DbSet<ReviewLike> ReviewLikes { get; set; }

    public virtual DbSet<Role> Roles { get; set; }

    public virtual DbSet<RoomType> RoomTypes { get; set; }

    public virtual DbSet<SearchHistory> SearchHistories { get; set; }

    public virtual DbSet<SocialAuthProvider> SocialAuthProviders { get; set; }

    public virtual DbSet<User> Users { get; set; }

    public virtual DbSet<UserDevice> UserDevices { get; set; }

    public virtual DbSet<UserPreference> UserPreferences { get; set; }

    public virtual DbSet<UserPreferenceAmenity> UserPreferenceAmenities { get; set; }

    public virtual DbSet<UserPreferenceRoomType> UserPreferenceRoomTypes { get; set; }

    public virtual DbSet<ViewHistory> ViewHistories { get; set; }

    public virtual DbSet<VwListingWithPackage> VwListingWithPackages { get; set; }

    public virtual DbSet<VwPendingFcmNotification> VwPendingFcmNotifications { get; set; }

    public virtual DbSet<VwUserFirebaseInfo> VwUserFirebaseInfos { get; set; }

    public virtual DbSet<Ward> Wards { get; set; }

    public virtual DbSet<ViewingAppointment> ViewingAppointments { get; set; }

    public virtual DbSet<Rental> Rentals { get; set; }



    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.UseCollation("Vietnamese_CI_AS");

        modelBuilder.Entity<AdminLog>(entity =>
        {
            entity.HasKey(e => e.LogId).HasName("PK__AdminLog__9E2397E029BBF650");

            entity.Property(e => e.LogId).HasColumnName("log_id");
            entity.Property(e => e.Action)
                .HasMaxLength(100)
                .HasColumnName("action");
            entity.Property(e => e.AdminId).HasColumnName("admin_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.Detail).HasColumnName("detail");
            entity.Property(e => e.IpAddress)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("ip_address");
            entity.Property(e => e.TargetId).HasColumnName("target_id");
            entity.Property(e => e.TargetType)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("target_type");

            entity.HasOne(d => d.Admin).WithMany(p => p.AdminLogs)
                .HasForeignKey(d => d.AdminId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__AdminLogs__admin__10216507");
        });

        modelBuilder.Entity<Amenity>(entity =>
        {
            entity.HasKey(e => e.AmenityId).HasName("PK__Amenitie__E908452D2D25BC0B");

            entity.HasIndex(e => e.Name, "UQ__Amenitie__72E12F1B32A541DF").IsUnique();

            entity.Property(e => e.AmenityId).HasColumnName("amenity_id");
            entity.Property(e => e.Category)
                .HasMaxLength(50)
                .HasColumnName("category");
            entity.Property(e => e.IconUrl)
                .HasMaxLength(500)
                .HasColumnName("icon_url");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.Name)
                .HasMaxLength(100)
                .HasColumnName("name");
        });

        modelBuilder.Entity<Banner>(entity =>
        {
            entity.HasKey(e => e.BannerId).HasName("PK__Banners__10373C34E9E7E7B1");

            entity.Property(e => e.BannerId).HasColumnName("banner_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.ImageUrl)
                .HasMaxLength(500)
                .HasColumnName("image_url");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.LinkUrl)
                .HasMaxLength(500)
                .HasColumnName("link_url");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.SortOrder)
                .HasDefaultValue(0)
                .HasColumnName("sort_order");
            entity.Property(e => e.StartDate).HasColumnName("start_date");
            entity.Property(e => e.CloudinaryPublicId)
                .HasMaxLength(300)
                .HasColumnName("cloudinary_public_id");
            entity.Property(e => e.Title)
                .HasMaxLength(200)
                .HasColumnName("title");

            entity.HasOne(d => d.Listing).WithMany(p => p.Banners)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__Banners__listing__29221CFB");
        });

        modelBuilder.Entity<Conversation>(entity =>
        {
            entity.HasKey(e => e.ConvId).HasName("PK__Conversa__E990F1A6789B9968");

            entity.HasIndex(e => new { e.ListingId, e.TenantId, e.LandlordId }, "UQ__Conversa__1BBD9884D444B65C").IsUnique();

            entity.Property(e => e.ConvId).HasColumnName("conv_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.LandlordId).HasColumnName("landlord_id");
            entity.Property(e => e.LastMsgAt).HasColumnName("last_msg_at");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.TenantId).HasColumnName("tenant_id");

            entity.HasOne(d => d.Landlord).WithMany(p => p.ConversationLandlords)
                .HasForeignKey(d => d.LandlordId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Conversat__landl__40058253");

            entity.HasOne(d => d.Listing).WithMany(p => p.Conversations)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__Conversat__listi__3E1D39E1");

            entity.HasOne(d => d.Tenant).WithMany(p => p.ConversationTenants)
                .HasForeignKey(d => d.TenantId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Conversat__tenan__3F115E1A");
        });

        modelBuilder.Entity<DailyStat>(entity =>
        {
            entity.HasKey(e => e.StatId).HasName("PK__DailySta__B8A52560F31C1AEE");

            entity.HasIndex(e => e.StatDate, "UQ__DailySta__38B70DF857B07B3F").IsUnique();

            entity.Property(e => e.StatId).HasColumnName("stat_id");
            entity.Property(e => e.ActiveListings)
                .HasDefaultValue(0)
                .HasColumnName("active_listings");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.FcmFailedCount)
                .HasDefaultValue(0)
                .HasColumnName("fcm_failed_count");
            entity.Property(e => e.FcmSentCount)
                .HasDefaultValue(0)
                .HasColumnName("fcm_sent_count");
            entity.Property(e => e.NewListings)
                .HasDefaultValue(0)
                .HasColumnName("new_listings");
            entity.Property(e => e.NewUsers)
                .HasDefaultValue(0)
                .HasColumnName("new_users");
            entity.Property(e => e.NewUsersFirebase)
                .HasDefaultValue(0)
                .HasColumnName("new_users_firebase");
            entity.Property(e => e.StatDate).HasColumnName("stat_date");
            entity.Property(e => e.CloudinaryDeleteCount)
                .HasDefaultValue(0)
                .HasColumnName("cloudinary_delete_count");
            entity.Property(e => e.CloudinaryUploadCount)
                .HasDefaultValue(0)
                .HasColumnName("cloudinary_upload_count");
            entity.Property(e => e.CloudinaryUploadMb)
                .HasDefaultValue(0m)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("cloudinary_upload_mb");
            entity.Property(e => e.TotalRevenue)
                .HasDefaultValue(0m)
                .HasColumnType("decimal(18, 0)")
                .HasColumnName("total_revenue");
            entity.Property(e => e.TotalSearches)
                .HasDefaultValue(0)
                .HasColumnName("total_searches");
        });

        modelBuilder.Entity<District>(entity =>
        {
            entity.HasKey(e => e.DistrictId).HasName("PK__District__2521322B6FEA412A");

            entity.Property(e => e.DistrictId).HasColumnName("district_id");
            entity.Property(e => e.DistrictCode)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("district_code");
            entity.Property(e => e.DistrictName)
                .HasMaxLength(100)
                .HasColumnName("district_name");
            entity.Property(e => e.ProvinceId).HasColumnName("province_id");

            entity.HasOne(d => d.Province).WithMany(p => p.Districts)
                .HasForeignKey(d => d.ProvinceId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Districts__provi__778AC167");
        });

        modelBuilder.Entity<Favorite>(entity =>
        {
            entity.HasKey(e => e.FavoriteId).HasName("PK__Favorite__46ACF4CBD7A53D4D");

            entity.HasIndex(e => new { e.UserId, e.ListingId }, "UQ__Favorite__E123B67919CB8DB2").IsUnique();

            entity.Property(e => e.FavoriteId).HasColumnName("favorite_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Listing).WithMany(p => p.Favorites)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__Favorites__listi__395884C4");

            entity.HasOne(d => d.User).WithMany(p => p.Favorites)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__Favorites__user___3864608B");
        });

        modelBuilder.Entity<CloudinaryFile>(entity =>
        {
            entity.HasKey(e => e.FileId).HasName("PK__Cloudina__07D884C60275D3F7");

            entity.HasIndex(e => new { e.RefType, e.RefId }, "IX_CloudinaryFiles_Ref");

            entity.HasIndex(e => new { e.UserId, e.ResourceType }, "IX_CloudinaryFiles_User");

            entity.HasIndex(e => e.PublicId, "UQ__Cloudina__3C21A5C7D53E2919").IsUnique();

            entity.Property(e => e.FileId).HasColumnName("file_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.DeletedAt).HasColumnName("deleted_at");
            entity.Property(e => e.DeliveryUrl)
                .HasMaxLength(500)
                .HasColumnName("delivery_url");
            entity.Property(e => e.FileSizeKb).HasColumnName("file_size_kb");
            entity.Property(e => e.Folder)
                .HasMaxLength(255)
                .HasColumnName("folder");
            entity.Property(e => e.Format)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("format");
            entity.Property(e => e.Height).HasColumnName("height");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.PublicId)
                .HasMaxLength(300)
                .HasColumnName("public_id");
            entity.Property(e => e.RefId).HasColumnName("ref_id");
            entity.Property(e => e.RefType)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("ref_type");
            entity.Property(e => e.ResourceType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("resource_type");
            entity.Property(e => e.SecureUrl)
                .HasMaxLength(500)
                .HasColumnName("secure_url");
            entity.Property(e => e.UploadStatus)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("uploaded")
                .HasColumnName("upload_status");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Width).HasColumnName("width");
            entity.Property(e => e.DurationSec).HasColumnName("duration_sec");

            entity.HasOne(d => d.User).WithMany(p => p.CloudinaryFiles)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Cloudinar__user___245D67DE");
        });

        modelBuilder.Entity<FirebaseTokenLog>(entity =>
        {
            entity.HasKey(e => e.LogId).HasName("PK__Firebase__9E2397E0E3745499");

            entity.Property(e => e.LogId).HasColumnName("log_id");
            entity.Property(e => e.ChangeReason)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("change_reason");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.DeviceId).HasColumnName("device_id");
            entity.Property(e => e.DeviceType)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("device_type");
            entity.Property(e => e.NewToken)
                .HasMaxLength(500)
                .HasColumnName("new_token");
            entity.Property(e => e.OldToken)
                .HasMaxLength(500)
                .HasColumnName("old_token");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Device).WithMany(p => p.FirebaseTokenLogs)
                .HasForeignKey(d => d.DeviceId)
                .HasConstraintName("FK__FirebaseT__devic__571DF1D5");

            entity.HasOne(d => d.User).WithMany(p => p.FirebaseTokenLogs)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__FirebaseT__user___5629CD9C");
        });

        modelBuilder.Entity<Invoice>(entity =>
        {
            entity.HasKey(e => e.InvoiceId).HasName("PK__Invoices__F58DFD49FE07EDB3");

            entity.HasIndex(e => e.LandlordId, "IX_Invoices_Landlord");

            entity.HasIndex(e => e.InvoiceCode, "UQ__Invoices__5ED70A354A34C1A2").IsUnique();

            entity.Property(e => e.InvoiceId).HasColumnName("invoice_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.DueDate).HasColumnName("due_date");
            entity.Property(e => e.InvoiceCode)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("invoice_code");
            entity.Property(e => e.InvoiceType)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasDefaultValue("post_package")
                .HasColumnName("invoice_type");
            entity.Property(e => e.LandlordId).HasColumnName("landlord_id");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.Note)
                .HasMaxLength(500)
                .HasColumnName("note");
            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.TotalAmount)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("total_amount");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Landlord).WithMany(p => p.Invoices)
                .HasForeignKey(d => d.LandlordId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Invoices__landlo__690797E6");

            entity.HasOne(d => d.Listing).WithMany(p => p.Invoices)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__Invoices__listin__69FBBC1F");

            entity.HasOne(d => d.Status).WithMany(p => p.Invoices)
                .HasForeignKey(d => d.StatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Invoices__status__6BE40491");
        });

        modelBuilder.Entity<Listing>(entity =>
        {
            entity.HasKey(e => e.ListingId).HasName("PK__Listings__89D8177461A03BBE");

            entity.ToTable("Listings", tb =>
                tb.HasTrigger("trg_Listings_ForcePendingOnInsert"));

            entity.HasIndex(e => e.DistrictId, "IX_Listings_District");

            entity.HasIndex(e => e.LandlordId, "IX_Listings_Landlord");

            entity.HasIndex(e => new { e.Latitude, e.Longitude }, "IX_Listings_LatLng");

            entity.HasIndex(e => e.Price, "IX_Listings_Price");

            entity.HasIndex(e => e.StatusId, "IX_Listings_Status");

            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.AllowPet)
                .HasDefaultValue(false)
                .HasColumnName("allow_pet");
            entity.Property(e => e.Area)
                .HasColumnType("decimal(8, 2)")
                .HasColumnName("area");
            entity.Property(e => e.AvailableFrom).HasColumnName("available_from");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.DistrictId).HasColumnName("district_id");
            entity.Property(e => e.ElectricPrice)
                .HasColumnType("decimal(10, 0)")
                .HasColumnName("electric_price");
            entity.Property(e => e.ExpiredAt).HasColumnName("expired_at");
            entity.Property(e => e.Floor).HasColumnName("floor");
            entity.Property(e => e.Image0)
                .HasMaxLength(500)
                .HasColumnName("image_0");
            entity.Property(e => e.Image1)
                .HasMaxLength(500)
                .HasColumnName("image_1");
            entity.Property(e => e.Image2)
                .HasMaxLength(500)
                .HasColumnName("image_2");
            entity.Property(e => e.Image3)
                .HasMaxLength(500)
                .HasColumnName("image_3");
            entity.Property(e => e.Image4)
                .HasMaxLength(500)
                .HasColumnName("image_4");
            entity.Property(e => e.Image5)
                .HasMaxLength(500)
                .HasColumnName("image_5");
            entity.Property(e => e.InternetPrice)
                .HasColumnType("decimal(10, 0)")
                .HasColumnName("internet_price");
            entity.Property(e => e.IsFeatured)
                .HasDefaultValue(false)
                .HasColumnName("is_featured");
            entity.Property(e => e.IsNew)
                .HasDefaultValue(true)
                .HasColumnName("is_new");
            entity.Property(e => e.IsVerified)
                .HasDefaultValue(false)
                .HasColumnName("is_verified");
            entity.Property(e => e.LandlordId).HasColumnName("landlord_id");
            entity.Property(e => e.Latitude).HasColumnName("latitude");
            entity.Property(e => e.Longitude).HasColumnName("longitude");
            entity.Property(e => e.MaxOccupants)
                .HasDefaultValue(1)
                .HasColumnName("max_occupants");
            entity.Property(e => e.ParkingPrice)
                .HasColumnType("decimal(10, 0)")
                .HasColumnName("parking_price");
            entity.Property(e => e.Price)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("price");
            entity.Property(e => e.ProvinceId).HasColumnName("province_id");
            entity.Property(e => e.SaveCount)
                .HasDefaultValue(0)
                .HasColumnName("save_count");
            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.CloudinaryFolder)
                .HasMaxLength(200)
                .HasColumnName("cloudinary_folder");
            entity.Property(e => e.StreetAddress)
                .HasMaxLength(300)
                .HasColumnName("street_address");
            entity.Property(e => e.Title)
                .HasMaxLength(200)
                .HasColumnName("title");
            entity.Property(e => e.TotalFloors).HasColumnName("total_floors");
            entity.Property(e => e.TypeId).HasColumnName("type_id");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");
            entity.Property(e => e.TotalRatingSum)
                .HasDefaultValue(0)
                .HasColumnName("total_rating_sum");
            entity.Property(e => e.ReviewCount)
                .HasDefaultValue(0)
                .HasColumnName("review_count");
            entity.Property(e => e.AverageRating)
                .HasDefaultValue(0.0)
                .HasColumnName("average_rating");
            entity.Property(e => e.ViewCount)
                .HasDefaultValue(0)
                .HasColumnName("view_count");
            entity.Property(e => e.WardId).HasColumnName("ward_id");
            entity.Property(e => e.WaterPrice)
                .HasColumnType("decimal(10, 0)")
                .HasColumnName("water_price");

            entity.HasOne(d => d.District).WithMany(p => p.Listings)
                .HasForeignKey(d => d.DistrictId)
                .HasConstraintName("FK__Listings__distri__04E4BC85");

            entity.HasOne(d => d.Landlord).WithMany(p => p.Listings)
                .HasForeignKey(d => d.LandlordId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Listings__landlo__00200768");

            entity.HasOne(d => d.Province).WithMany(p => p.Listings)
                .HasForeignKey(d => d.ProvinceId)
                .HasConstraintName("FK__Listings__provin__03F0984C");

            entity.HasOne(d => d.Status).WithMany(p => p.Listings)
                .HasForeignKey(d => d.StatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Listings__status__02084FDA");

            entity.HasOne(d => d.Type).WithMany(p => p.Listings)
                .HasForeignKey(d => d.TypeId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Listings__type_i__01142BA1");

            entity.HasOne(d => d.Ward).WithMany(p => p.Listings)
                .HasForeignKey(d => d.WardId)
                .HasConstraintName("FK__Listings__ward_i__05D8E0BE");
        });

        modelBuilder.Entity<ListingAmenity>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__ListingA__3213E83FBADA26D7");

            entity.HasIndex(e => new { e.ListingId, e.AmenityId }, "UQ__ListingA__47489327C764B631").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.AmenityId).HasColumnName("amenity_id");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");

            entity.HasOne(d => d.Amenity).WithMany(p => p.ListingAmenities)
                .HasForeignKey(d => d.AmenityId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__ListingAm__ameni__1332DBDC");

            entity.HasOne(d => d.Listing).WithMany(p => p.ListingAmenities)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__ListingAm__listi__123EB7A3");
        });

        modelBuilder.Entity<ListingImage>(entity =>
        {
            entity.HasKey(e => e.ImageId).HasName("PK__ListingI__DC9AC9550DD1AB19");

            entity.Property(e => e.ImageId).HasColumnName("image_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.CloudinaryPublicId)
                .HasMaxLength(300)
                .HasColumnName("cloudinary_public_id");
            entity.Property(e => e.CloudinaryUrl)
                .HasMaxLength(500)
                .HasColumnName("cloudinary_url");
            entity.Property(e => e.Format)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("format");
            entity.Property(e => e.Height).HasColumnName("height");
            entity.Property(e => e.IsCover)
                .HasDefaultValue(false)
                .HasColumnName("is_cover");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.SecureUrl)
                .HasMaxLength(500)
                .HasColumnName("secure_url");
            entity.Property(e => e.SortOrder)
                .HasDefaultValue(0)
                .HasColumnName("sort_order");
            entity.Property(e => e.Width).HasColumnName("width");

            entity.HasOne(d => d.Listing).WithMany(p => p.ListingImages)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__ListingIm__listi__160F4887");
        });

        modelBuilder.Entity<ListingPostPackage>(entity =>
        {
            entity.HasKey(e => e.LppId).HasName("PK__ListingP__AC85A4D93F613C17");

            entity.Property(e => e.LppId).HasColumnName("lpp_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.PackageId).HasColumnName("package_id");
            entity.Property(e => e.PaymentId).HasColumnName("payment_id");
            entity.Property(e => e.StartDate).HasColumnName("start_date");

            entity.HasOne(d => d.Listing).WithMany(p => p.ListingPostPackages)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__ListingPo__listi__01D345B0");

            entity.HasOne(d => d.Package).WithMany(p => p.ListingPostPackages)
                .HasForeignKey(d => d.PackageId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__ListingPo__packa__02C769E9");

            entity.HasOne(d => d.Payment).WithMany(p => p.ListingPostPackages)
                .HasForeignKey(d => d.PaymentId)
                .HasConstraintName("FK__ListingPo__payme__03BB8E22");
        });

        modelBuilder.Entity<ListingPriceHistory>(entity =>
        {
            entity.HasKey(e => e.HistoryId).HasName("PK__ListingP__096AA2E9847D3663");

            entity.ToTable("ListingPriceHistory");

            entity.Property(e => e.HistoryId).HasColumnName("history_id");
            entity.Property(e => e.ChangedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("changed_at");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.NewPrice)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("new_price");
            entity.Property(e => e.OldPrice)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("old_price");

            entity.HasOne(d => d.Listing).WithMany(p => p.ListingPriceHistories)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__ListingPr__listi__1F98B2C1");
        });

        modelBuilder.Entity<ListingStatus>(entity =>
        {
            entity.HasKey(e => e.StatusId).HasName("PK__ListingS__3683B5319725B3E7");

            entity.ToTable("ListingStatus");

            entity.HasIndex(e => e.StatusName, "UQ__ListingS__501B3753E5776770").IsUnique();

            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.StatusName)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("status_name");
        });

        modelBuilder.Entity<ListingVideo>(entity =>
        {
            entity.HasKey(e => e.VideoId).HasName("PK__ListingV__E8F11E10866CBCEA");

            entity.Property(e => e.VideoId).HasColumnName("video_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.CloudinaryPublicId)
                .HasMaxLength(300)
                .HasColumnName("cloudinary_public_id");
            entity.Property(e => e.CloudinaryUrl)
                .HasMaxLength(500)
                .HasColumnName("cloudinary_url");
            entity.Property(e => e.DurationSec).HasColumnName("duration_sec");
            entity.Property(e => e.FileSizeKb).HasColumnName("file_size_kb");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.ThumbnailUrl)
                .HasMaxLength(500)
                .HasColumnName("thumbnail_url");

            entity.HasOne(d => d.Listing).WithMany(p => p.ListingVideos)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__ListingVi__listi__1BC821DD");
        });

        modelBuilder.Entity<Message>(entity =>
        {
            entity.HasKey(e => e.MessageId).HasName("PK__Messages__0BBF6EE653034451");

            entity.HasIndex(e => new { e.ConvId, e.SentAt }, "IX_Messages_Conv").IsDescending(false, true);

            entity.Property(e => e.MessageId).HasColumnName("message_id");
            entity.Property(e => e.Content).HasColumnName("content");
            entity.Property(e => e.ConvId).HasColumnName("conv_id");
            entity.Property(e => e.FcmSent)
                .HasDefaultValue(false)
                .HasColumnName("fcm_sent");
            entity.Property(e => e.FcmSentAt).HasColumnName("fcm_sent_at");
            entity.Property(e => e.FileUrl)
                .HasMaxLength(500)
                .HasColumnName("file_url");
            entity.Property(e => e.IsRead)
                .HasDefaultValue(false)
                .HasColumnName("is_read");
            entity.Property(e => e.MsgType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("text")
                .HasColumnName("msg_type");
            entity.Property(e => e.SenderId).HasColumnName("sender_id");
            entity.Property(e => e.SentAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("sent_at");
            entity.Property(e => e.CloudinaryPublicId)
                .HasMaxLength(300)
                .HasColumnName("cloudinary_public_id");

            entity.HasOne(d => d.Conv).WithMany(p => p.Messages)
                .HasForeignKey(d => d.ConvId)
                .HasConstraintName("FK__Messages__conv_i__43D61337");

            entity.HasOne(d => d.Sender).WithMany(p => p.Messages)
                .HasForeignKey(d => d.SenderId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Messages__sender__44CA3770");
        });

        modelBuilder.Entity<Notification>(entity =>
        {
            entity.HasKey(e => e.NotifId).HasName("PK__Notifica__CDF18E6C8EE38E4B");

            entity.HasIndex(e => new { e.FcmStatus, e.SentAt }, "IX_Notifications_FcmPending").HasFilter("([fcm_status]='pending')");

            entity.HasIndex(e => new { e.UserId, e.IsRead, e.SentAt }, "IX_Notifications_User").IsDescending(false, false, true);

            entity.Property(e => e.NotifId).HasColumnName("notif_id");
            entity.Property(e => e.Body).HasColumnName("body");
            entity.Property(e => e.FcmErrorMsg)
                .HasMaxLength(300)
                .HasColumnName("fcm_error_msg");
            entity.Property(e => e.FcmSentAt).HasColumnName("fcm_sent_at");
            entity.Property(e => e.FcmStatus)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("pending")
                .HasColumnName("fcm_status");
            entity.Property(e => e.IsRead)
                .HasDefaultValue(false)
                .HasColumnName("is_read");
            entity.Property(e => e.NotifType)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("notif_type");
            entity.Property(e => e.RefId).HasColumnName("ref_id");
            entity.Property(e => e.RefType)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("ref_type");
            entity.Property(e => e.SentAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("sent_at");
            entity.Property(e => e.Title)
                .HasMaxLength(200)
                .HasColumnName("title");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.Notifications)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__Notificat__user___4B7734FF");
        });

        modelBuilder.Entity<OtpCode>(entity =>
        {
            entity.HasKey(e => e.OtpId).HasName("PK__OtpCodes__AEE354354C67DA9D");

            entity.Property(e => e.OtpId).HasColumnName("otp_id");
            entity.Property(e => e.Code)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("code");
            entity.Property(e => e.Contact)
                .HasMaxLength(150)
                .HasColumnName("contact");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.ExpiresAt).HasColumnName("expires_at");
            entity.Property(e => e.IsUsed)
                .HasDefaultValue(false)
                .HasColumnName("is_used");
            entity.Property(e => e.OtpType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("otp_type");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.OtpCodes)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__OtpCodes__user_i__4BAC3F29");
        });

        modelBuilder.Entity<Payment>(entity =>
        {
            entity.HasKey(e => e.PaymentId).HasName("PK__Payments__ED1FC9EACD91395B");

            entity.HasIndex(e => e.InvoiceId, "IX_Payments_Invoice");

            entity.Property(e => e.PaymentId).HasColumnName("payment_id");
            entity.Property(e => e.Amount)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("amount");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.GatewayResponse).HasColumnName("gateway_response");
            entity.Property(e => e.InvoiceId).HasColumnName("invoice_id");
            entity.Property(e => e.MethodId).HasColumnName("method_id");
            entity.Property(e => e.PaidAt).HasColumnName("paid_at");
            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.TransactionRef)
                .HasMaxLength(200)
                .IsUnicode(false)
                .HasColumnName("transaction_ref");

            entity.HasOne(d => d.Invoice).WithMany(p => p.Payments)
                .HasForeignKey(d => d.InvoiceId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Payments__invoic__70A8B9AE");

            entity.HasOne(d => d.Method).WithMany(p => p.Payments)
                .HasForeignKey(d => d.MethodId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Payments__method__719CDDE7");

            entity.HasOne(d => d.Status).WithMany(p => p.Payments)
                .HasForeignKey(d => d.StatusId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Payments__status__72910220");
        });

        modelBuilder.Entity<PaymentMethod>(entity =>
        {
            entity.HasKey(e => e.MethodId).HasName("PK__PaymentM__747727B61EF38BC2");

            entity.HasIndex(e => e.MethodName, "UQ__PaymentM__2DA2FAEE8378AA99").IsUnique();

            entity.Property(e => e.MethodId).HasColumnName("method_id");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.LogoUrl)
                .HasMaxLength(500)
                .HasColumnName("logo_url");
            entity.Property(e => e.MethodName)
                .HasMaxLength(50)
                .HasColumnName("method_name");
        });

        modelBuilder.Entity<PaymentStatus>(entity =>
        {
            entity.HasKey(e => e.StatusId).HasName("PK__PaymentS__3683B53187FD0E73");

            entity.ToTable("PaymentStatus");

            entity.HasIndex(e => e.StatusName, "UQ__PaymentS__501B3753CA8F81BA").IsUnique();

            entity.Property(e => e.StatusId).HasColumnName("status_id");
            entity.Property(e => e.StatusName)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("status_name");
        });

        modelBuilder.Entity<PostPackage>(entity =>
        {
            entity.HasKey(e => e.PackageId).HasName("PK__PostPack__63846AE8D274A127");

            entity.Property(e => e.PackageId).HasColumnName("package_id");
            entity.Property(e => e.AllowBanner).HasColumnName("allow_banner");
            entity.Property(e => e.BadgeType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("badge_type");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.Description)
                .HasMaxLength(500)
                .HasColumnName("description");
            entity.Property(e => e.DurationDays)
                .HasDefaultValue(30)
                .HasColumnName("duration_days");
            entity.Property(e => e.HasAnalytics).HasColumnName("has_analytics");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.IsHighlighted).HasColumnName("is_highlighted");
            entity.Property(e => e.MaxImages)
                .HasDefaultValue(1)
                .HasColumnName("max_images");
            entity.Property(e => e.MaxVideos).HasColumnName("max_videos");
            entity.Property(e => e.PackageName)
                .HasMaxLength(100)
                .HasColumnName("package_name");
            entity.Property(e => e.PackageType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("package_type");
            entity.Property(e => e.Price)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("price");
            entity.Property(e => e.Priority).HasColumnName("priority");
        });

        modelBuilder.Entity<Province>(entity =>
        {
            entity.HasKey(e => e.ProvinceId).HasName("PK__Province__08DCB60FE7A8EBF8");

            entity.HasIndex(e => e.ProvinceCode, "UQ__Province__D0B09FC6726DF02C").IsUnique();

            entity.Property(e => e.ProvinceId).HasColumnName("province_id");
            entity.Property(e => e.ProvinceCode)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("province_code");
            entity.Property(e => e.ProvinceName)
                .HasMaxLength(100)
                .HasColumnName("province_name");
        });

        modelBuilder.Entity<Report>(entity =>
        {
            entity.HasKey(e => e.ReportId).HasName("PK__Reports__779B7C58405BE725");

            entity.Property(e => e.ReportId).HasColumnName("report_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.Description).HasColumnName("description");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.Reason)
                .HasMaxLength(100)
                .HasColumnName("reason");
            entity.Property(e => e.ReporterId).HasColumnName("reporter_id");
            entity.Property(e => e.ResolvedAt).HasColumnName("resolved_at");
            entity.Property(e => e.ResolvedBy).HasColumnName("resolved_by");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("pending")
                .HasColumnName("status");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.Listing).WithMany(p => p.Reports)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__Reports__listing__09746778");

            entity.HasOne(d => d.Reporter).WithMany(p => p.ReportReporters)
                .HasForeignKey(d => d.ReporterId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Reports__reporte__0880433F");

            entity.HasOne(d => d.ResolvedByNavigation).WithMany(p => p.ReportResolvedByNavigations)
                .HasForeignKey(d => d.ResolvedBy)
                .HasConstraintName("FK__Reports__resolve__0C50D423");

            entity.HasOne(d => d.User).WithMany(p => p.ReportUsers)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__Reports__user_id__0A688BB1");
        });

        modelBuilder.Entity<Review>(entity =>
        {
            entity.HasKey(e => e.ReviewId).HasName("PK__Reviews__60883D90D0DA281C");

            entity.HasIndex(e => new { e.ListingId, e.ReviewerId }, "UX_Reviews_Listing_Reviewer_Type")
                .HasFilter("[type] = 'review' AND [is_deleted] = 0")
                .IsUnique();

            entity.Property(e => e.ReviewId).HasColumnName("review_id");
            entity.Property(e => e.Comment).HasColumnName("comment");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.IsApproved)
                .HasDefaultValue(false)
                .HasColumnName("is_approved");
            entity.Property(e => e.LandlordReply).HasColumnName("landlord_reply");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.Rating).HasColumnName("rating");
            entity.Property(e => e.RatingCleanness).HasColumnName("rating_cleanness");
            entity.Property(e => e.RatingLocation).HasColumnName("rating_location");
            entity.Property(e => e.RatingPrice).HasColumnName("rating_price");
            entity.Property(e => e.RatingSecurity).HasColumnName("rating_security");
            entity.Property(e => e.RepliedAt).HasColumnName("replied_at");
            entity.Property(e => e.ReviewerId).HasColumnName("reviewer_id");
            entity.Property(e => e.Type)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValueSql("('review')")
                .HasColumnName("type");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValueSql("('approved')")
                .HasColumnName("status");
            entity.Property(e => e.ReportCount)
                .HasDefaultValueSql("(0)")
                .HasColumnName("report_count");
            entity.Property(e => e.IsDeleted)
                .HasDefaultValueSql("(0)")
                .HasColumnName("is_deleted");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Listing).WithMany(p => p.Reviews)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__Reviews__listing__5224328E");

            entity.HasOne(d => d.Reviewer).WithMany(p => p.Reviews)
                .HasForeignKey(d => d.ReviewerId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Reviews__reviewe__531856C7");
        });

        modelBuilder.Entity<ReviewImage>(entity =>
        {
            entity.HasKey(e => e.ImgId).HasName("PK__ReviewIm__6F16A71CEFA4259B");

            entity.Property(e => e.ImgId).HasColumnName("img_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.ImageUrl)
                .HasMaxLength(500)
                .HasColumnName("image_url");
            entity.Property(e => e.ReviewId).HasColumnName("review_id");
            entity.Property(e => e.CloudinaryPublicId)
                .HasMaxLength(300)
                .HasColumnName("cloudinary_public_id");

            entity.HasOne(d => d.Review).WithMany(p => p.ReviewImages)
                .HasForeignKey(d => d.ReviewId)
                .HasConstraintName("FK__ReviewIma__revie__5D95E53A");
        });

        modelBuilder.Entity<ReviewLike>(entity =>
        {
            entity.HasKey(e => e.ReviewLikeId).HasName("PK_ReviewLikes");

            entity.HasIndex(e => new { e.ReviewId, e.UserId }, "UX_ReviewLikes_Review_User")
                .IsUnique();

            entity.Property(e => e.ReviewLikeId).HasColumnName("review_like_id");
            entity.Property(e => e.ReviewId).HasColumnName("review_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");

            entity.HasOne(d => d.Review).WithMany(p => p.ReviewLikes)
                .HasForeignKey(d => d.ReviewId)
                .HasConstraintName("FK_ReviewLikes_Reviews");

            entity.HasOne(d => d.User).WithMany(p => p.ReviewLikes)
                .HasForeignKey(d => d.UserId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ReviewLikes_Users");
        });

        modelBuilder.Entity<Role>(entity =>
        {
            entity.HasKey(e => e.RoleId).HasName("PK__Roles__760965CC6FA0517D");

            entity.HasIndex(e => e.RoleName, "UQ__Roles__783254B1FCD14E4C").IsUnique();

            entity.Property(e => e.RoleId).HasColumnName("role_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.Description)
                .HasMaxLength(255)
                .HasColumnName("description");
            entity.Property(e => e.RoleName)
                .HasMaxLength(50)
                .HasColumnName("role_name");
        });

        modelBuilder.Entity<RoomType>(entity =>
        {
            entity.HasKey(e => e.TypeId).HasName("PK__RoomType__2C000598948BF3E3");

            entity.HasIndex(e => e.TypeName, "UQ__RoomType__543C4FD9D72EA3FF").IsUnique();

            entity.Property(e => e.TypeId).HasColumnName("type_id");
            entity.Property(e => e.IconUrl)
                .HasMaxLength(500)
                .HasColumnName("icon_url");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.SortOrder)
                .HasDefaultValue(0)
                .HasColumnName("sort_order");
            entity.Property(e => e.TypeName)
                .HasMaxLength(100)
                .HasColumnName("type_name");
        });

        modelBuilder.Entity<SearchHistory>(entity =>
        {
            entity.HasKey(e => e.SearchId).HasName("PK__SearchHi__B302268D95751060");

            entity.ToTable("SearchHistory");

            entity.Property(e => e.SearchId).HasColumnName("search_id");
            entity.Property(e => e.FilterJson).HasColumnName("filter_json");
            entity.Property(e => e.Keyword)
                .HasMaxLength(300)
                .HasColumnName("keyword");
            entity.Property(e => e.ResultCount).HasColumnName("result_count");
            entity.Property(e => e.SearchedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("searched_at");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.SearchHistories)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__SearchHis__user___2EDAF651");
        });

        modelBuilder.Entity<SocialAuthProvider>(entity =>
        {
            entity.HasKey(e => e.ProviderId).HasName("PK__SocialAu__00E21310F6A1190E");

            entity.HasIndex(e => new { e.Provider, e.ProviderUid }, "UQ__SocialAu__67C29E52098FF703").IsUnique();

            entity.Property(e => e.ProviderId).HasColumnName("provider_id");
            entity.Property(e => e.AccessToken).HasColumnName("access_token");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.FirebaseUid)
                .HasMaxLength(128)
                .HasColumnName("firebase_uid");
            entity.Property(e => e.Provider)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("provider");
            entity.Property(e => e.ProviderUid)
                .HasMaxLength(200)
                .HasColumnName("provider_uid");
            entity.Property(e => e.RefreshToken).HasColumnName("refresh_token");
            entity.Property(e => e.TokenExpiresAt).HasColumnName("token_expires_at");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.SocialAuthProviders)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__SocialAut__user___46E78A0C");
        });

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.UserId).HasName("PK__Users__B9BE370F1E24AA82");

            entity.HasIndex(e => e.FirebaseUid, "IX_Users_FirebaseUid").HasFilter("([firebase_uid] IS NOT NULL)");

            entity.HasIndex(e => e.FirebaseUid, "UQ__Users__1E65B7F889AD7AA7").IsUnique();

            entity.HasIndex(e => e.Email, "UQ__Users__AB6E616461B16984").IsUnique();

            entity.HasIndex(e => e.Phone, "UQ__Users__B43B145FD3CEF708").IsUnique();

            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.AvatarSource)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("upload")
                .HasColumnName("avatar_source");
            entity.Property(e => e.AvatarUrl)
                .HasMaxLength(500)
                .HasColumnName("avatar_url");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.DateOfBirth).HasColumnName("date_of_birth");
            entity.Property(e => e.Email)
                .HasMaxLength(150)
                .HasColumnName("email");
            entity.Property(e => e.FirebaseProvider)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("firebase_provider");
            entity.Property(e => e.FirebaseUid)
                .HasMaxLength(128)
                .HasColumnName("firebase_uid");
            entity.Property(e => e.FullName)
                .HasMaxLength(100)
                .HasColumnName("full_name");
            entity.Property(e => e.Gender).HasColumnName("gender");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.IsVerified)
                .HasDefaultValue(false)
                .HasColumnName("is_verified");

            entity.Property(e => e.IsEmailVerified)
                .HasDefaultValue(false)
                .HasColumnName("is_email_verified");

            entity.Property(e => e.LastLogin).HasColumnName("last_login");
            entity.Property(e => e.PasswordHash)
                .HasMaxLength(255)
                .HasColumnName("password_hash");
            entity.Property(e => e.Phone)
                .HasMaxLength(15)
                .IsUnicode(false)
                .HasColumnName("phone");
            entity.Property(e => e.RoleId).HasColumnName("role_id");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Role).WithMany(p => p.Users)
                .HasForeignKey(d => d.RoleId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Users__role_id__3E52440B");
        });

        modelBuilder.Entity<UserDevice>(entity =>
        {
            entity.HasKey(e => e.DeviceId).HasName("PK__UserDevi__3B085D8B3C3B5357");

            entity.Property(e => e.DeviceId).HasColumnName("device_id");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.DeviceName)
                .HasMaxLength(100)
                .HasColumnName("device_name");
            entity.Property(e => e.DeviceToken)
                .HasMaxLength(500)
                .HasColumnName("device_token");
            entity.Property(e => e.DeviceType)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("device_type");
            entity.Property(e => e.FcmErrorAt).HasColumnName("fcm_error_at");
            entity.Property(e => e.FcmLastError)
                .HasMaxLength(200)
                .HasColumnName("fcm_last_error");
            entity.Property(e => e.IsActive)
                .HasDefaultValue(true)
                .HasColumnName("is_active");
            entity.Property(e => e.LastActive)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("last_active");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.UserDevices)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__UserDevic__user___5070F446");
        });

        modelBuilder.Entity<UserPreference>(entity =>
        {
            entity.HasKey(e => e.PrefId).HasName("PK__UserPref__F94C4B3D660141BE");

            entity.HasIndex(e => e.UserId, "UQ__UserPref__B9BE370E89BFEFB3").IsUnique();

            entity.Property(e => e.PrefId).HasColumnName("pref_id");
            entity.Property(e => e.AllowPet).HasColumnName("allow_pet");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.Latitude).HasColumnName("latitude");
            entity.Property(e => e.Longitude).HasColumnName("longitude");
            entity.Property(e => e.MaxPrice)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("max_price");
            entity.Property(e => e.MinPrice)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("min_price");
            entity.Property(e => e.OnboardingDone)
                .HasDefaultValue(false)
                .HasColumnName("onboarding_done");
            entity.Property(e => e.PreferredArea)
                .HasMaxLength(200)
                .HasColumnName("preferred_area");
            entity.Property(e => e.SearchRadiusKm)
                .HasDefaultValue(5)
                .HasColumnName("search_radius_km");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithOne(p => p.UserPreference)
                .HasForeignKey<UserPreference>(d => d.UserId)
                .HasConstraintName("FK__UserPrefe__user___6477ECF3");
        });

        modelBuilder.Entity<UserPreferenceAmenity>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__UserPref__3213E83FF280E4B1");

            entity.HasIndex(e => new { e.PrefId, e.AmenityId }, "UQ__UserPref__37DCCF6E33613952").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.AmenityId).HasColumnName("amenity_id");
            entity.Property(e => e.PrefId).HasColumnName("pref_id");

            entity.HasOne(d => d.Amenity).WithMany(p => p.UserPreferenceAmenities)
                .HasForeignKey(d => d.AmenityId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__UserPrefe__ameni__71D1E811");

            entity.HasOne(d => d.Pref).WithMany(p => p.UserPreferenceAmenities)
                .HasForeignKey(d => d.PrefId)
                .HasConstraintName("FK__UserPrefe__pref___70DDC3D8");
        });

        modelBuilder.Entity<UserPreferenceRoomType>(entity =>
        {
            entity.HasKey(e => e.Id).HasName("PK__UserPref__3213E83F374B3641");

            entity.HasIndex(e => new { e.PrefId, e.TypeId }, "UQ__UserPref__6B8C4B6590348C71").IsUnique();

            entity.Property(e => e.Id).HasColumnName("id");
            entity.Property(e => e.PrefId).HasColumnName("pref_id");
            entity.Property(e => e.TypeId).HasColumnName("type_id");

            entity.HasOne(d => d.Pref).WithMany(p => p.UserPreferenceRoomTypes)
                .HasForeignKey(d => d.PrefId)
                .HasConstraintName("FK__UserPrefe__pref___6C190EBB");

            entity.HasOne(d => d.Type).WithMany(p => p.UserPreferenceRoomTypes)
                .HasForeignKey(d => d.TypeId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__UserPrefe__type___6D0D32F4");
        });

        modelBuilder.Entity<ViewHistory>(entity =>
        {
            entity.HasKey(e => e.ViewId).HasName("PK__ViewHist__B5A34EE2B108165C");

            entity.ToTable("ViewHistory");

            entity.HasIndex(e => new { e.UserId, e.ViewedAt }, "IX_ViewHistory_User").IsDescending(false, true);

            entity.Property(e => e.ViewId).HasColumnName("view_id");
            entity.Property(e => e.DurationSec).HasColumnName("duration_sec");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.ViewedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("viewed_at");

            entity.HasOne(d => d.Listing).WithMany(p => p.ViewHistories)
                .HasForeignKey(d => d.ListingId)
                .HasConstraintName("FK__ViewHisto__listi__339FAB6E");

            entity.HasOne(d => d.User).WithMany(p => p.ViewHistories)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__ViewHisto__user___32AB8735");
        });

        modelBuilder.Entity<VwListingWithPackage>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("vw_ListingWithPackage");

            entity.Property(e => e.AllowBanner).HasColumnName("allow_banner");
            entity.Property(e => e.Area)
                .HasColumnType("decimal(8, 2)")
                .HasColumnName("area");
            entity.Property(e => e.BadgeType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("badge_type");
            entity.Property(e => e.CoverImage)
                .HasMaxLength(500)
                .HasColumnName("cover_image");
            entity.Property(e => e.HasAnalytics).HasColumnName("has_analytics");
            entity.Property(e => e.IsHighlighted).HasColumnName("is_highlighted");
            entity.Property(e => e.LandlordFirebaseUid)
                .HasMaxLength(128)
                .HasColumnName("landlord_firebase_uid");
            entity.Property(e => e.LandlordName)
                .HasMaxLength(100)
                .HasColumnName("landlord_name");
            entity.Property(e => e.LandlordPhone)
                .HasMaxLength(15)
                .IsUnicode(false)
                .HasColumnName("landlord_phone");
            entity.Property(e => e.Latitude).HasColumnName("latitude");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.Longitude).HasColumnName("longitude");
            entity.Property(e => e.MaxImages).HasColumnName("max_images");
            entity.Property(e => e.PackageDaysLeft).HasColumnName("package_days_left");
            entity.Property(e => e.PackageExpiresAt).HasColumnName("package_expires_at");
            entity.Property(e => e.PackageName)
                .HasMaxLength(100)
                .HasColumnName("package_name");
            entity.Property(e => e.PackageType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("package_type");
            entity.Property(e => e.Price)
                .HasColumnType("decimal(15, 0)")
                .HasColumnName("price");
            entity.Property(e => e.SaveCount).HasColumnName("save_count");
            entity.Property(e => e.StatusName)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("status_name");
            entity.Property(e => e.CloudinaryFolder)
                .HasMaxLength(200)
                .HasColumnName("cloudinary_folder");
            entity.Property(e => e.StreetAddress)
                .HasMaxLength(300)
                .HasColumnName("street_address");
            entity.Property(e => e.Title)
                .HasMaxLength(200)
                .HasColumnName("title");
            entity.Property(e => e.ViewCount).HasColumnName("view_count");
        });

        modelBuilder.Entity<VwPendingFcmNotification>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("vw_PendingFcmNotifications");

            entity.Property(e => e.Body).HasColumnName("body");
            entity.Property(e => e.DeviceId).HasColumnName("device_id");
            entity.Property(e => e.DeviceToken)
                .HasMaxLength(500)
                .HasColumnName("device_token");
            entity.Property(e => e.DeviceType)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("device_type");
            entity.Property(e => e.NotifId).HasColumnName("notif_id");
            entity.Property(e => e.NotifType)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("notif_type");
            entity.Property(e => e.RefId).HasColumnName("ref_id");
            entity.Property(e => e.RefType)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("ref_type");
            entity.Property(e => e.SentAt).HasColumnName("sent_at");
            entity.Property(e => e.Title)
                .HasMaxLength(200)
                .HasColumnName("title");
            entity.Property(e => e.UserId).HasColumnName("user_id");
        });

        modelBuilder.Entity<VwUserFirebaseInfo>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("vw_UserFirebaseInfo");

            entity.Property(e => e.ActiveDevices).HasColumnName("active_devices");
            entity.Property(e => e.AuthMethod)
                .HasMaxLength(13)
                .IsUnicode(false)
                .HasColumnName("auth_method");
            entity.Property(e => e.AvatarSource)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("avatar_source");
            entity.Property(e => e.AvatarUrl)
                .HasMaxLength(500)
                .HasColumnName("avatar_url");
            entity.Property(e => e.Email)
                .HasMaxLength(150)
                .HasColumnName("email");
            entity.Property(e => e.FirebaseProvider)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("firebase_provider");
            entity.Property(e => e.FirebaseUid)
                .HasMaxLength(128)
                .HasColumnName("firebase_uid");
            entity.Property(e => e.FullName)
                .HasMaxLength(100)
                .HasColumnName("full_name");
            entity.Property(e => e.IsActive).HasColumnName("is_active");
            entity.Property(e => e.IsVerified).HasColumnName("is_verified");
            entity.Property(e => e.Phone)
                .HasMaxLength(15)
                .IsUnicode(false)
                .HasColumnName("phone");
            entity.Property(e => e.RoleName)
                .HasMaxLength(50)
                .HasColumnName("role_name");
            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.UsesFirebase).HasColumnName("uses_firebase");
        });

        modelBuilder.Entity<Ward>(entity =>
        {
            entity.HasKey(e => e.WardId).HasName("PK__Wards__396B899DE5C8769C");

            entity.Property(e => e.WardId).HasColumnName("ward_id");
            entity.Property(e => e.DistrictId).HasColumnName("district_id");
            entity.Property(e => e.WardCode)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("ward_code");
            entity.Property(e => e.WardName)
                .HasMaxLength(100)
                .HasColumnName("ward_name");

            entity.HasOne(d => d.District).WithMany(p => p.Wards)
                .HasForeignKey(d => d.DistrictId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Wards__district___7A672E12");
        });

        modelBuilder.Entity<ViewingAppointment>(entity =>
        {
            entity.HasKey(e => e.AppointmentId).HasName("PK_ViewingAppointments");

            entity.ToTable("ViewingAppointments");

            entity.Property(e => e.AppointmentId).HasColumnName("appointment_id");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.TenantId).HasColumnName("tenant_id");
            entity.Property(e => e.LandlordId).HasColumnName("landlord_id");
            entity.Property(e => e.ScheduledAt).HasColumnName("scheduled_at");

            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValueSql("('pending')")
                .HasColumnName("status");

            entity.Property(e => e.TenantNote)
                .HasMaxLength(500)
                .HasColumnName("tenant_note");

            entity.Property(e => e.LandlordNote)
                .HasMaxLength(500)
                .HasColumnName("landlord_note");

            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");

            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Listing).WithMany(p => p.ViewingAppointments)
                .HasForeignKey(d => d.ListingId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ViewingAppointments_Listings");

            entity.HasOne(d => d.Tenant).WithMany(p => p.ViewingAppointmentTenants)
                .HasForeignKey(d => d.TenantId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ViewingAppointments_Tenants");

            entity.HasOne(d => d.Landlord).WithMany(p => p.ViewingAppointmentLandlords)
                .HasForeignKey(d => d.LandlordId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_ViewingAppointments_Landlords");
        });

        modelBuilder.Entity<Rental>(entity =>
        {
            entity.HasKey(e => e.RentalId).HasName("PK_Rentals");

            entity.ToTable("Rentals");

            entity.Property(e => e.RentalId).HasColumnName("rental_id");
            entity.Property(e => e.ListingId).HasColumnName("listing_id");
            entity.Property(e => e.TenantId).HasColumnName("tenant_id");
            entity.Property(e => e.LandlordId).HasColumnName("landlord_id");
            entity.Property(e => e.StartDate).HasColumnName("start_date");
            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValueSql("('active')")
                .HasColumnName("status");
            entity.Property(e => e.CreatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("created_at");
            entity.Property(e => e.UpdatedAt)
                .HasDefaultValueSql("(getdate())")
                .HasColumnName("updated_at");

            entity.HasOne(d => d.Listing).WithMany(p => p.Rentals)
                .HasForeignKey(d => d.ListingId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Rentals_Listings");

            entity.HasOne(d => d.Tenant).WithMany(p => p.RentalTenants)
                .HasForeignKey(d => d.TenantId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Rentals_Tenants");

            entity.HasOne(d => d.Landlord).WithMany(p => p.RentalLandlords)
                .HasForeignKey(d => d.LandlordId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Rentals_Landlords");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
