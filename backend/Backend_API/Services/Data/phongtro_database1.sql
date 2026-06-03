-- ============================================================
--  PHÒNG TRỌ APP - SQL SERVER DATABASE SCHEMA
--  Phiên bản : 1.3 (Cloudinary Integration)
--  Ngày cập nhật : 2026-03-20
--  Thay đổi so với v1.2 (Firebase Storage):
--    + Xóa bảng FirebaseStorageFiles
--    + Thêm bảng CloudinaryFiles (quản lý file Cloudinary)
--    + Đổi storage_path → cloudinary_public_id
--    + Đổi storage_folder → cloudinary_folder
--    + Thêm cột width/height/format trong ảnh
--    + Cập nhật tất cả bảng liên quan đến file
--    + Cập nhật SP xử lý file
--    + Giữ nguyên Firebase Auth + FCM (không thay đổi)
-- ============================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'PhongTroDB')
BEGIN
    ALTER DATABASE PhongTroDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PhongTroDB;
END
GO

CREATE DATABASE PhongTroDB
    COLLATE Vietnamese_CI_AS;
GO

USE PhongTroDB;
GO

-- ============================================================
-- 1. USERS & AUTHENTICATION - NGƯỜI DÙNG & XÁC THỰC
-- ============================================================

CREATE TABLE Roles (
    role_id     INT           PRIMARY KEY IDENTITY(1,1),
    role_name   NVARCHAR(50)  NOT NULL UNIQUE,
    -- 'tenant' | 'landlord' | 'admin'
    description NVARCHAR(255) NULL,
    created_at  DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- BẢNG USERS
-- Firebase Auth: Xác thực người dùng (giữ nguyên)
-- Cloudinary   : Lưu avatar_url = Cloudinary URL
-- ============================================================
CREATE TABLE Users (
    user_id       BIGINT        PRIMARY KEY IDENTITY(1,1),
    full_name     NVARCHAR(100) NOT NULL,
    email         NVARCHAR(150) NULL UNIQUE,
    phone         VARCHAR(15)   NULL UNIQUE,
    password_hash NVARCHAR(255) NULL,

    -- ── AVATAR - CLOUDINARY ──────────────────────────────────
    avatar_url         NVARCHAR(500) NULL,
    -- Cloudinary Delivery URL
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      v1234567890/avatars/user_456.jpg'

    avatar_public_id   NVARCHAR(300) NULL,
    -- Cloudinary Public ID để xóa/transform ảnh
    -- VD: 'avatars/user_456'
    -- Dùng khi user đổi avatar → xóa ảnh cũ trên Cloudinary
    -- ─────────────────────────────────────────────────────────

    date_of_birth DATE          NULL,
    gender        TINYINT       NULL,
    -- 0 = Nam | 1 = Nữ | 2 = Khác
    role_id       INT           NOT NULL REFERENCES Roles(role_id),
    is_verified   BIT           DEFAULT 0,
    is_active     BIT           DEFAULT 1,
    last_login    DATETIME2     NULL,

    -- ── FIREBASE AUTH FIELDS (giữ nguyên) ───────────────────
    firebase_uid      NVARCHAR(128) NULL UNIQUE,
    -- UID duy nhất Firebase cấp

    firebase_provider VARCHAR(30)   NULL,
    -- 'password' | 'google.com' | 'facebook.com' | NULL

    avatar_source     VARCHAR(20)   NULL DEFAULT 'upload',
    -- 'upload'   : User tự upload lên Cloudinary
    -- 'google'   : Lấy từ Google Account (URL Google, không phải Cloudinary)
    -- 'facebook' : Lấy từ Facebook Account
    -- 'default'  : Ảnh mặc định hệ thống
    -- Ghi chú: Nếu 'upload' → avatar_public_id có giá trị
    --          Nếu 'google'/'facebook' → avatar_public_id = NULL
    --          vì ảnh Google/Facebook không lưu trên Cloudinary
    -- ─────────────────────────────────────────────────────────

    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

CREATE INDEX IX_Users_FirebaseUid
    ON Users (firebase_uid)
    WHERE firebase_uid IS NOT NULL;

-- ============================================================
-- BẢNG SocialAuthProviders - GIỮ NGUYÊN (Firebase Auth)
-- ============================================================
CREATE TABLE SocialAuthProviders (
    provider_id      BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id          BIGINT        NOT NULL
                         REFERENCES Users(user_id) ON DELETE CASCADE,
    provider         VARCHAR(30)   NOT NULL,
    -- 'google.com' | 'facebook.com' | 'phone' | 'password'
    provider_uid     NVARCHAR(200) NOT NULL,
    firebase_uid     NVARCHAR(128) NULL,
    access_token     NVARCHAR(MAX) NULL,
    -- Firebase ID Token (JWT ~1 giờ)
    refresh_token    NVARCHAR(MAX) NULL,
    token_expires_at DATETIME2     NULL,
    created_at       DATETIME2     DEFAULT GETDATE(),
    updated_at       DATETIME2     DEFAULT GETDATE(),
    UNIQUE (provider, provider_uid)
);

-- ============================================================
-- BẢNG OtpCodes - GIỮ NGUYÊN
-- ============================================================
CREATE TABLE OtpCodes (
    otp_id     BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id    BIGINT        NULL REFERENCES Users(user_id),
    contact    NVARCHAR(150) NOT NULL,
    otp_type   VARCHAR(20)   NOT NULL,
    -- 'register' | 'forgot_password' | 'verify' | 'change_phone'
    code       VARCHAR(10)   NOT NULL,
    is_used    BIT           DEFAULT 0,
    expires_at DATETIME2     NOT NULL,
    created_at DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- BẢNG UserDevices - GIỮ NGUYÊN (Firebase FCM)
-- ============================================================
CREATE TABLE UserDevices (
    device_id     BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id       BIGINT        NOT NULL
                      REFERENCES Users(user_id) ON DELETE CASCADE,
    device_token  NVARCHAR(500) NOT NULL,
    -- Firebase FCM Token
    device_type   VARCHAR(10)   NOT NULL,
    -- 'ios' | 'android' | 'web'
    device_name   NVARCHAR(100) NULL,
    is_active     BIT           DEFAULT 1,
    last_active   DATETIME2     DEFAULT GETDATE(),
    fcm_last_error    NVARCHAR(200) NULL,
    fcm_error_at      DATETIME2     NULL,
    created_at    DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- BẢNG FirebaseTokenLogs - GIỮ NGUYÊN (Firebase FCM)
-- ============================================================
CREATE TABLE FirebaseTokenLogs (
    log_id        BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id       BIGINT        NOT NULL
                      REFERENCES Users(user_id) ON DELETE CASCADE,
    device_id     BIGINT        NULL
                      REFERENCES UserDevices(device_id),
    old_token     NVARCHAR(500) NULL,
    new_token     NVARCHAR(500) NOT NULL,
    change_reason VARCHAR(50)   NULL,
    -- 'app_reinstall' | 'token_refresh' | 'user_logout' | 'first_login'
    device_type   VARCHAR(10)   NULL,
    created_at    DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- 2. ONBOARDING & USER PREFERENCES
-- ============================================================

CREATE TABLE RoomTypes (
    type_id   INT           PRIMARY KEY IDENTITY(1,1),
    type_name NVARCHAR(100) NOT NULL UNIQUE,
    icon_url  NVARCHAR(500) NULL,
    -- Cloudinary URL cho icon loại phòng
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      v123/icons/room_type_1.png'
    sort_order INT          DEFAULT 0,
    is_active  BIT          DEFAULT 1
);

CREATE TABLE Amenities (
    amenity_id INT           PRIMARY KEY IDENTITY(1,1),
    name       NVARCHAR(100) NOT NULL UNIQUE,
    icon_url   NVARCHAR(500) NULL,
    -- Cloudinary URL cho icon tiện ích
    category   NVARCHAR(50)  NULL,
    -- 'basic' | 'security' | 'comfort'
    is_active  BIT           DEFAULT 1
);

CREATE TABLE UserPreferences (
    pref_id          BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id          BIGINT        NOT NULL UNIQUE
                         REFERENCES Users(user_id) ON DELETE CASCADE,
    preferred_area   NVARCHAR(200) NULL,
    min_price        DECIMAL(15,0) NULL,
    max_price        DECIMAL(15,0) NULL,
    allow_pet        BIT           NULL,
    latitude         FLOAT         NULL,
    longitude        FLOAT         NULL,
    search_radius_km INT           NULL DEFAULT 5,
    onboarding_done  BIT           DEFAULT 0,
    created_at       DATETIME2     DEFAULT GETDATE(),
    updated_at       DATETIME2     DEFAULT GETDATE()
);

CREATE TABLE UserPreferenceRoomTypes (
    id      BIGINT PRIMARY KEY IDENTITY(1,1),
    pref_id BIGINT NOT NULL
                REFERENCES UserPreferences(pref_id) ON DELETE CASCADE,
    type_id INT    NOT NULL REFERENCES RoomTypes(type_id),
    UNIQUE (pref_id, type_id)
);

CREATE TABLE UserPreferenceAmenities (
    id         BIGINT PRIMARY KEY IDENTITY(1,1),
    pref_id    BIGINT NOT NULL
                   REFERENCES UserPreferences(pref_id) ON DELETE CASCADE,
    amenity_id INT    NOT NULL REFERENCES Amenities(amenity_id),
    UNIQUE (pref_id, amenity_id)
);

-- ============================================================
-- 3. ĐỊA LÝ
-- ============================================================

CREATE TABLE Provinces (
    province_id   INT           PRIMARY KEY IDENTITY(1,1),
    province_name NVARCHAR(100) NOT NULL,
    province_code VARCHAR(10)   NULL UNIQUE
);

CREATE TABLE Districts (
    district_id   INT           PRIMARY KEY IDENTITY(1,1),
    province_id   INT           NOT NULL
                      REFERENCES Provinces(province_id),
    district_name NVARCHAR(100) NOT NULL,
    district_code VARCHAR(10)   NULL
);

CREATE TABLE Wards (
    ward_id     INT           PRIMARY KEY IDENTITY(1,1),
    district_id INT           NOT NULL
                    REFERENCES Districts(district_id),
    ward_name   NVARCHAR(100) NOT NULL,
    ward_code   VARCHAR(10)   NULL
);

-- ============================================================
-- 4. LISTINGS - CẬP NHẬT CLOUDINARY
-- ============================================================

CREATE TABLE ListingStatus (
    status_id   INT         PRIMARY KEY IDENTITY(1,1),
    status_name VARCHAR(30) NOT NULL UNIQUE
    -- 'active' | 'rented' | 'hidden' | 'pending' | 'rejected'
);

CREATE TABLE Listings (
    listing_id    BIGINT        PRIMARY KEY IDENTITY(1,1),
    landlord_id   BIGINT        NOT NULL REFERENCES Users(user_id),
    type_id       INT           NOT NULL REFERENCES RoomTypes(type_id),
    status_id     INT           NOT NULL REFERENCES ListingStatus(status_id),

    title         NVARCHAR(200) NOT NULL,
    description   NVARCHAR(MAX) NULL,
    price         DECIMAL(15,0) NOT NULL,
    area          DECIMAL(8,2)  NOT NULL,
    floor         INT           NULL,
    total_floors  INT           NULL,
    max_occupants INT           NULL DEFAULT 1,

    -- Địa chỉ
    province_id   INT  NULL REFERENCES Provinces(province_id),
    district_id   INT  NULL REFERENCES Districts(district_id),
    ward_id       INT  NULL REFERENCES Wards(ward_id),
    street_address NVARCHAR(300) NOT NULL,
    latitude      FLOAT NULL,
    longitude     FLOAT NULL,

    -- Trạng thái & nhãn
    is_verified  BIT DEFAULT 0,
    is_featured  BIT DEFAULT 0,
    is_new       BIT DEFAULT 1,
    allow_pet    BIT DEFAULT 0,

    -- ── 6 ẢNH CỐ ĐỊNH - CLOUDINARY DELIVERY URL ─────────────
    -- Cloudinary tự tối ưu: resize, format, quality
    -- Flutter dùng CachedNetworkImage với URL này
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      f_auto,q_auto,w_800/listings/123/cover.jpg'
    image_0 NVARCHAR(500) NULL,  -- Ảnh bìa (bắt buộc khi active)
    image_1 NVARCHAR(500) NULL,
    image_2 NVARCHAR(500) NULL,
    image_3 NVARCHAR(500) NULL,
    image_4 NVARCHAR(500) NULL,
    image_5 NVARCHAR(500) NULL,
    -- ─────────────────────────────────────────────────────────

    -- ── CLOUDINARY FOLDER ────────────────────────────────────
    cloudinary_folder  NVARCHAR(200) NULL,
    -- Tên thư mục Cloudinary chứa tất cả file của tin này
    -- VD: 'listings/123'
    -- Dùng khi xóa tin → gọi Cloudinary API:
    --   DELETE /resources/image?prefix=listings/123/
    -- Cloudinary xóa toàn bộ file trong folder đó
    -- ─────────────────────────────────────────────────────────

    -- Chi phí dịch vụ
    electric_price  DECIMAL(10,0) NULL,
    water_price     DECIMAL(10,0) NULL,
    internet_price  DECIMAL(10,0) NULL,
    parking_price   DECIMAL(10,0) NULL,

    -- Thống kê
    view_count INT DEFAULT 0,
    save_count INT DEFAULT 0,

    -- Thời hạn
    available_from DATE      NULL,
    expired_at     DATETIME2 NULL,
    created_at     DATETIME2 DEFAULT GETDATE(),
    updated_at     DATETIME2 DEFAULT GETDATE(),

    CONSTRAINT CK_cover_image_required
        CHECK (status_id <> 1 OR image_0 IS NOT NULL)
    -- status_id = 1 là 'active' → phải có ảnh bìa
);

CREATE INDEX IX_Listings_LatLng   ON Listings (latitude, longitude);
CREATE INDEX IX_Listings_Price    ON Listings (price);
CREATE INDEX IX_Listings_District ON Listings (district_id);
CREATE INDEX IX_Listings_Status   ON Listings (status_id);
CREATE INDEX IX_Listings_Landlord ON Listings (landlord_id);

CREATE TABLE ListingAmenities (
    id         BIGINT PRIMARY KEY IDENTITY(1,1),
    listing_id BIGINT NOT NULL
                   REFERENCES Listings(listing_id) ON DELETE CASCADE,
    amenity_id INT    NOT NULL REFERENCES Amenities(amenity_id),
    UNIQUE (listing_id, amenity_id)
);

-- ============================================================
-- BẢNG ListingImages - CLOUDINARY
-- Mỗi ảnh có public_id riêng để quản lý trên Cloudinary
-- ============================================================
CREATE TABLE ListingImages (
    image_id          BIGINT        PRIMARY KEY IDENTITY(1,1),
    listing_id        BIGINT        NOT NULL
                          REFERENCES Listings(listing_id) ON DELETE CASCADE,

    -- ── CLOUDINARY FIELDS ────────────────────────────────────
    cloudinary_url    NVARCHAR(500) NOT NULL,
    -- Cloudinary Delivery URL đã tối ưu
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      f_auto,q_auto/listings/123/img_001.jpg'

    cloudinary_public_id NVARCHAR(300) NOT NULL,
    -- Public ID dùng để:
    --   1. Xóa ảnh: cloudinary.uploader.destroy(public_id)
    --   2. Transform: cloudinary.url(public_id, {width: 400})
    -- VD: 'listings/123/img_001'

    secure_url        NVARCHAR(500) NULL,
    -- Cloudinary Secure URL (https, không có transform)
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      v1234567890/listings/123/img_001.jpg'
    -- Lưu để fallback nếu cần URL gốc

    width             INT           NULL,
    -- Chiều rộng ảnh gốc (px) - Cloudinary trả về khi upload
    height            INT           NULL,
    -- Chiều cao ảnh gốc (px)
    format            VARCHAR(10)   NULL,
    -- Định dạng: 'jpg' | 'png' | 'webp' | 'heic'
    -- ─────────────────────────────────────────────────────────

    is_cover          BIT           DEFAULT 0,
    sort_order        INT           DEFAULT 0,
    created_at        DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- BẢNG ListingVideos - CLOUDINARY
-- ============================================================
CREATE TABLE ListingVideos (
    video_id          BIGINT        PRIMARY KEY IDENTITY(1,1),
    listing_id        BIGINT        NOT NULL
                          REFERENCES Listings(listing_id) ON DELETE CASCADE,

    -- ── CLOUDINARY FIELDS ────────────────────────────────────
    cloudinary_url    NVARCHAR(500) NOT NULL,
    -- Cloudinary Video Delivery URL
    -- VD: 'https://res.cloudinary.com/myapp/video/upload/
    --      q_auto/listings/123/tour.mp4'

    cloudinary_public_id NVARCHAR(300) NOT NULL,
    -- Public ID để xóa video
    -- VD: 'listings/123/tour'

    thumbnail_url     NVARCHAR(500) NULL,
    -- Cloudinary tự tạo thumbnail từ video
    -- VD: 'https://res.cloudinary.com/myapp/video/upload/
    --      so_0,f_jpg/listings/123/tour.jpg'
    -- (Dùng transformation: so_0 = giây thứ 0, f_jpg = format jpg)

    duration_sec      INT           NULL,
    -- Thời lượng video (giây) - Cloudinary trả về khi upload
    file_size_kb      INT           NULL,
    -- Dung lượng video (KB)
    -- ─────────────────────────────────────────────────────────

    created_at DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE ListingPriceHistory (
    history_id BIGINT        PRIMARY KEY IDENTITY(1,1),
    listing_id BIGINT        NOT NULL
                   REFERENCES Listings(listing_id) ON DELETE CASCADE,
    old_price  DECIMAL(15,0) NOT NULL,
    new_price  DECIMAL(15,0) NOT NULL,
    changed_at DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- 5. CLOUDINARY FILES - THAY THẾ FirebaseStorageFiles
-- ============================================================
-- Mục đích: Quản lý tập trung TẤT CẢ file trên Cloudinary
-- Giúp:
--   - Biết file nào đang dùng, file nào mồ côi (orphan)
--   - Background Job dọn file mồ côi:
--       is_active = 0 VÀ deleted_at < 24h trước
--       → Gọi cloudinary.uploader.destroy(public_id)
--   - Thống kê dung lượng theo user (file_size_kb)
--   - Kiểm soát giới hạn upload theo gói đăng tin
-- ============================================================
CREATE TABLE CloudinaryFiles (
    file_id      BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id      BIGINT        NOT NULL REFERENCES Users(user_id),
    -- Người upload file

    -- ── CLOUDINARY IDENTIFIER ────────────────────────────────
    public_id    NVARCHAR(300) NOT NULL UNIQUE,
    -- Cloudinary Public ID - định danh duy nhất mỗi file
    -- VD: 'listings/123/images/cover'
    -- VD: 'avatars/456/profile'
    -- VD: 'reviews/789/photo1'
    -- Dùng để: xóa, transform, generate URL

    secure_url   NVARCHAR(500) NOT NULL,
    -- URL HTTPS đầy đủ Cloudinary trả về sau upload
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      v1234567890/listings/123/images/cover.jpg'

    delivery_url NVARCHAR(500) NULL,
    -- URL có transformation tối ưu (f_auto,q_auto)
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      f_auto,q_auto/listings/123/images/cover'
    -- App Flutter dùng URL này để hiển thị (tự chọn format)
    -- ─────────────────────────────────────────────────────────

    -- ── CLOUDINARY METADATA ──────────────────────────────────
    resource_type VARCHAR(10)   NOT NULL DEFAULT 'image',
    -- Loại resource Cloudinary:
    -- 'image'  : Ảnh (jpg, png, webp...)
    -- 'video'  : Video (mp4, mov...)
    -- 'raw'    : File khác (pdf, doc...)

    format        VARCHAR(10)   NULL,
    -- 'jpg' | 'png' | 'webp' | 'mp4' | 'pdf' ...

    width         INT           NULL,
    -- Chiều rộng (px) - chỉ cho ảnh/video
    height        INT           NULL,
    -- Chiều cao (px)
    duration_sec  INT           NULL,
    -- Thời lượng (giây) - chỉ cho video
    file_size_kb  INT           NULL,
    -- Dung lượng file (KB) - từ bytes Cloudinary trả về / 1024
    -- ─────────────────────────────────────────────────────────

    -- ── PHÂN LOẠI & LIÊN KẾT ────────────────────────────────
    folder        NVARCHAR(200) NULL,
    -- Tên thư mục Cloudinary
    -- VD: 'listings/123' | 'avatars' | 'reviews/789'

    ref_type      VARCHAR(50)   NULL,
    -- Đối tượng sở hữu file:
    -- 'listing' : Ảnh/video tin đăng
    -- 'review'  : Ảnh trong đánh giá
    -- 'avatar'  : Ảnh đại diện user
    -- 'message' : File/ảnh trong chat
    -- 'banner'  : Ảnh banner trang chủ
    -- 'icon'    : Icon loại phòng / tiện ích

    ref_id        BIGINT        NULL,
    -- ID đối tượng sở hữu
    -- VD: listing_id, review_id, user_id, banner_id
    -- ─────────────────────────────────────────────────────────

    -- ── TRẠNG THÁI ───────────────────────────────────────────
    is_active     BIT           DEFAULT 1,
    -- 1 = File đang được dùng
    -- 0 = Đã xóa logic (Soft Delete)
    --     → Background Job sẽ gọi Cloudinary API xóa thật

    upload_status VARCHAR(20)   DEFAULT 'completed',
    -- Trạng thái upload:
    -- 'uploading' : Đang upload (Flutter đang gửi)
    -- 'completed' : Upload xong, Cloudinary đã nhận
    -- 'failed'    : Upload lỗi
    -- Dùng để dọn file 'uploading' quá 1 giờ (upload bị lỗi giữa chừng)
    -- ─────────────────────────────────────────────────────────

    created_at  DATETIME2 DEFAULT GETDATE(),
    deleted_at  DATETIME2 NULL
    -- Thời điểm đánh dấu xóa (Soft Delete)
    -- Background Job dọn khi deleted_at < NOW - 24h
);

-- Index tìm file theo đối tượng sở hữu
CREATE INDEX IX_CloudinaryFiles_Ref
    ON CloudinaryFiles (ref_type, ref_id)
    WHERE is_active = 1;

-- Index tìm file của một user
CREATE INDEX IX_CloudinaryFiles_User
    ON CloudinaryFiles (user_id, resource_type)
    WHERE is_active = 1;

-- Index Background Job dọn file mồ côi
CREATE INDEX IX_CloudinaryFiles_Orphan
    ON CloudinaryFiles (is_active, deleted_at)
    WHERE is_active = 0;

-- ============================================================
-- 6. BANNER - CLOUDINARY
-- ============================================================
CREATE TABLE Banners (
    banner_id    INT           PRIMARY KEY IDENTITY(1,1),
    title        NVARCHAR(200) NULL,

    -- ── CLOUDINARY FIELDS ────────────────────────────────────
    image_url    NVARCHAR(500) NOT NULL,
    -- Cloudinary Delivery URL cho ảnh banner

    cloudinary_public_id NVARCHAR(300) NULL,
    -- Public ID để xóa banner trên Cloudinary khi không dùng
    -- VD: 'banners/banner_001'
    -- ─────────────────────────────────────────────────────────

    link_url     NVARCHAR(500) NULL,
    listing_id   BIGINT        NULL REFERENCES Listings(listing_id),
    sort_order   INT           DEFAULT 0,
    is_active    BIT           DEFAULT 1,
    start_date   DATETIME2     NULL,
    end_date     DATETIME2     NULL,
    created_at   DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- 7. TÌM KIẾM & YÊU THÍCH
-- ============================================================

CREATE TABLE SearchHistory (
    search_id    BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id      BIGINT        NOT NULL
                     REFERENCES Users(user_id) ON DELETE CASCADE,
    keyword      NVARCHAR(300) NOT NULL,
    filter_json  NVARCHAR(MAX) NULL,
    result_count INT           NULL,
    searched_at  DATETIME2     DEFAULT GETDATE()
);

CREATE TABLE ViewHistory (
    view_id      BIGINT    PRIMARY KEY IDENTITY(1,1),
    user_id      BIGINT    NOT NULL
                     REFERENCES Users(user_id) ON DELETE CASCADE,
    listing_id   BIGINT    NOT NULL
                     REFERENCES Listings(listing_id) ON DELETE CASCADE,
    viewed_at    DATETIME2 DEFAULT GETDATE(),
    duration_sec INT       NULL
);

CREATE INDEX IX_ViewHistory_User
    ON ViewHistory (user_id, viewed_at DESC);

CREATE TABLE Favorites (
    favorite_id BIGINT    PRIMARY KEY IDENTITY(1,1),
    user_id     BIGINT    NOT NULL
                    REFERENCES Users(user_id) ON DELETE CASCADE,
    listing_id  BIGINT    NOT NULL
                    REFERENCES Listings(listing_id) ON DELETE CASCADE,
    created_at  DATETIME2 DEFAULT GETDATE(),
    UNIQUE (user_id, listing_id)
);

-- ============================================================
-- 8. CHAT - FCM (giữ nguyên) + CLOUDINARY (file đính kèm)
-- ============================================================

CREATE TABLE Conversations (
    conv_id     BIGINT    PRIMARY KEY IDENTITY(1,1),
    listing_id  BIGINT    NULL REFERENCES Listings(listing_id),
    tenant_id   BIGINT    NOT NULL REFERENCES Users(user_id),
    landlord_id BIGINT    NOT NULL REFERENCES Users(user_id),
    last_msg_at DATETIME2 NULL,
    created_at  DATETIME2 DEFAULT GETDATE(),
    UNIQUE (listing_id, tenant_id, landlord_id)
);

-- ============================================================
-- BẢNG Messages - CLOUDINARY cho file đính kèm
-- ============================================================
CREATE TABLE Messages (
    message_id   BIGINT        PRIMARY KEY IDENTITY(1,1),
    conv_id      BIGINT        NOT NULL
                     REFERENCES Conversations(conv_id) ON DELETE CASCADE,
    sender_id    BIGINT        NOT NULL REFERENCES Users(user_id),
    content      NVARCHAR(MAX) NULL,
    msg_type     VARCHAR(20)   DEFAULT 'text',
    -- 'text' | 'image' | 'file' | 'system'

    -- ── CLOUDINARY - FILE ĐÍNH KÈM ───────────────────────────
    file_url          NVARCHAR(500) NULL,
    -- Cloudinary Delivery URL (nếu gửi ảnh/file)
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      f_auto,q_auto/messages/conv_10/img_001.jpg'

    cloudinary_public_id NVARCHAR(300) NULL,
    -- Public ID để xóa file khi cần
    -- VD: 'messages/conv_10/img_001'
    -- ─────────────────────────────────────────────────────────

    is_read  BIT DEFAULT 0,

    -- ── FIREBASE FCM (giữ nguyên) ─────────────────────────────
    fcm_sent    BIT       DEFAULT 0,
    -- 0 = Dùng SignalR (user online)
    -- 1 = Gửi FCM (user offline)
    fcm_sent_at DATETIME2 NULL,
    -- ─────────────────────────────────────────────────────────

    sent_at DATETIME2 DEFAULT GETDATE()
);

CREATE INDEX IX_Messages_Conv
    ON Messages (conv_id, sent_at DESC);

-- ============================================================
-- 9. NOTIFICATIONS - FIREBASE FCM (giữ nguyên)
-- ============================================================

CREATE TABLE Notifications (
    notif_id   BIGINT        PRIMARY KEY IDENTITY(1,1),
    user_id    BIGINT        NOT NULL
                   REFERENCES Users(user_id) ON DELETE CASCADE,
    title      NVARCHAR(200) NOT NULL,
    body       NVARCHAR(MAX) NULL,
    notif_type VARCHAR(50)   NULL,
    -- 'new_message' | 'listing_match' | 'payment' | 'system'
    -- 'vip_expiring' | 'review_reply'
    ref_id     BIGINT        NULL,
    ref_type   VARCHAR(50)   NULL,
    -- 'listing' | 'payment' | 'conversation' | 'review'
    is_read    BIT           DEFAULT 0,

    -- ── FIREBASE FCM TRACKING (giữ nguyên) ───────────────────
    fcm_status    VARCHAR(20)   DEFAULT 'pending',
    -- 'pending' | 'sent' | 'failed' | 'skipped' | 'no_token'
    fcm_sent_at   DATETIME2     NULL,
    fcm_error_msg NVARCHAR(300) NULL,
    -- ─────────────────────────────────────────────────────────

    sent_at DATETIME2 DEFAULT GETDATE()
);

CREATE INDEX IX_Notifications_User
    ON Notifications (user_id, is_read, sent_at DESC);

CREATE INDEX IX_Notifications_FcmPending
    ON Notifications (fcm_status, sent_at)
    WHERE fcm_status = 'pending';

-- ============================================================
-- 10. ĐÁNH GIÁ - CLOUDINARY
-- ============================================================

CREATE TABLE Reviews (
    review_id        BIGINT        PRIMARY KEY IDENTITY(1,1),
    listing_id       BIGINT        NOT NULL
                         REFERENCES Listings(listing_id) ON DELETE CASCADE,
    reviewer_id      BIGINT        NOT NULL REFERENCES Users(user_id),
    rating           TINYINT       NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment          NVARCHAR(MAX) NULL,
    rating_location  TINYINT       NULL CHECK (rating_location BETWEEN 1 AND 5),
    rating_price     TINYINT       NULL CHECK (rating_price BETWEEN 1 AND 5),
    rating_cleanness TINYINT       NULL CHECK (rating_cleanness BETWEEN 1 AND 5),
    rating_security  TINYINT       NULL CHECK (rating_security BETWEEN 1 AND 5),
    is_approved      BIT           DEFAULT 0,
    landlord_reply   NVARCHAR(MAX) NULL,
    replied_at       DATETIME2     NULL,
    created_at       DATETIME2     DEFAULT GETDATE(),
    updated_at       DATETIME2     DEFAULT GETDATE(),
    UNIQUE (listing_id, reviewer_id)
);

-- ============================================================
-- BẢNG ReviewImages - CLOUDINARY
-- ============================================================
CREATE TABLE ReviewImages (
    img_id       BIGINT        PRIMARY KEY IDENTITY(1,1),
    review_id    BIGINT        NOT NULL
                     REFERENCES Reviews(review_id) ON DELETE CASCADE,

    -- ── CLOUDINARY FIELDS ────────────────────────────────────
    image_url    NVARCHAR(500) NOT NULL,
    -- Cloudinary Delivery URL

    cloudinary_public_id NVARCHAR(300) NOT NULL,
    -- Public ID để xóa ảnh khi review bị xóa
    -- VD: 'reviews/789/photo1'
    -- ─────────────────────────────────────────────────────────

    created_at DATETIME2 DEFAULT GETDATE()
);

CREATE TABLE ReviewLikes (
    review_like_id BIGINT PRIMARY KEY IDENTITY(1,1),
    review_id      BIGINT NOT NULL REFERENCES Reviews(review_id) ON DELETE CASCADE,
    user_id        BIGINT NOT NULL REFERENCES Users(user_id),
    created_at     DATETIME2 DEFAULT GETDATE(),
    UNIQUE (review_id, user_id)
);

-- ============================================================
-- 11. THANH TOÁN & HÓA ĐƠN
-- ============================================================

CREATE TABLE PaymentMethods (
    method_id   INT           PRIMARY KEY IDENTITY(1,1),
    method_name NVARCHAR(50)  NOT NULL UNIQUE,
    -- 'bank_transfer' | 'momo' | 'vnpay' | 'zalopay' | 'cash'
    logo_url    NVARCHAR(500) NULL,
    -- Cloudinary URL cho logo phương thức thanh toán
    -- VD: 'https://res.cloudinary.com/myapp/image/upload/
    --      v123/payment/momo_logo.png'
    is_active   BIT           DEFAULT 1
);

CREATE TABLE PaymentStatus (
    status_id   INT         PRIMARY KEY IDENTITY(1,1),
    status_name VARCHAR(30) NOT NULL UNIQUE
    -- 'pending' | 'success' | 'failed' | 'refunded'
);

CREATE TABLE Invoices (
    invoice_id   BIGINT        PRIMARY KEY IDENTITY(1,1),
    landlord_id  BIGINT        NOT NULL REFERENCES Users(user_id),
    listing_id   BIGINT        NULL REFERENCES Listings(listing_id),
    invoice_code VARCHAR(50)   NOT NULL UNIQUE,
    invoice_type VARCHAR(30)   NOT NULL DEFAULT 'post_package',
    total_amount DECIMAL(15,0) NOT NULL,
    due_date     DATE          NOT NULL,
    note         NVARCHAR(500) NULL,
    status_id    INT           NOT NULL
                     REFERENCES PaymentStatus(status_id),
    created_at   DATETIME2     DEFAULT GETDATE(),
    updated_at   DATETIME2     DEFAULT GETDATE()
);

CREATE INDEX IX_Invoices_Landlord ON Invoices (landlord_id);

CREATE TABLE Payments (
    payment_id       BIGINT        PRIMARY KEY IDENTITY(1,1),
    invoice_id       BIGINT        NOT NULL REFERENCES Invoices(invoice_id),
    method_id        INT           NOT NULL
                         REFERENCES PaymentMethods(method_id),
    status_id        INT           NOT NULL
                         REFERENCES PaymentStatus(status_id),
    amount           DECIMAL(15,0) NOT NULL,
    transaction_ref  VARCHAR(200)  NULL,
    gateway_response NVARCHAR(MAX) NULL,
    paid_at          DATETIME2     NULL,
    created_at       DATETIME2     DEFAULT GETDATE()
);

CREATE INDEX IX_Payments_Invoice ON Payments (invoice_id);

-- ============================================================
-- 12. GÓI ĐĂNG TIN VIP
-- ============================================================

CREATE TABLE PostPackages (
    package_id     INT           PRIMARY KEY IDENTITY(1,1),
    package_name   NVARCHAR(100) NOT NULL,
    package_type   VARCHAR(20)   NOT NULL,
    -- 'free' | 'vip' | 'featured'
    duration_days  INT           NOT NULL DEFAULT 30,
    price          DECIMAL(15,0) NOT NULL DEFAULT 0,
    priority       INT           NOT NULL DEFAULT 0,
    max_images     INT           NOT NULL DEFAULT 1,
    -- Số ảnh tối đa → Giới hạn upload Cloudinary
    max_videos     INT           NOT NULL DEFAULT 0,
    -- Số video tối đa → Giới hạn upload Cloudinary
    allow_banner   BIT           NOT NULL DEFAULT 0,
    badge_type     VARCHAR(20)   NULL,
    -- NULL | 'vip' | 'featured'
    has_analytics  BIT           NOT NULL DEFAULT 0,
    is_highlighted BIT           NOT NULL DEFAULT 0,
    description    NVARCHAR(500) NULL,
    is_active      BIT           NOT NULL DEFAULT 1,
    created_at     DATETIME2     DEFAULT GETDATE()
);

CREATE TABLE ListingPostPackages (
    lpp_id     BIGINT    PRIMARY KEY IDENTITY(1,1),
    listing_id BIGINT    NOT NULL
                   REFERENCES Listings(listing_id) ON DELETE CASCADE,
    package_id INT       NOT NULL REFERENCES PostPackages(package_id),
    payment_id BIGINT    NULL REFERENCES Payments(payment_id),
    start_date DATETIME2 NOT NULL,
    end_date   DATETIME2 NOT NULL,
    is_active  BIT       DEFAULT 1,
    created_at DATETIME2 DEFAULT GETDATE()
);

-- ============================================================
-- 13. BÁO CÁO VI PHẠM
-- ============================================================

CREATE TABLE Reports (
    report_id   BIGINT        PRIMARY KEY IDENTITY(1,1),
    reporter_id BIGINT        NOT NULL REFERENCES Users(user_id),
    listing_id  BIGINT        NULL REFERENCES Listings(listing_id),
    user_id     BIGINT        NULL REFERENCES Users(user_id),
    reason      NVARCHAR(100) NOT NULL,
    description NVARCHAR(MAX) NULL,
    status      VARCHAR(20)   DEFAULT 'pending',
    -- 'pending' | 'resolved' | 'dismissed'
    resolved_by BIGINT        NULL REFERENCES Users(user_id),
    resolved_at DATETIME2     NULL,
    created_at  DATETIME2     DEFAULT GETDATE()
);

-- ============================================================
-- 14. ADMIN & THỐNG KÊ
-- ============================================================

CREATE TABLE AdminLogs (
    log_id      BIGINT        PRIMARY KEY IDENTITY(1,1),
    admin_id    BIGINT        NOT NULL REFERENCES Users(user_id),
    action      NVARCHAR(100) NOT NULL,
    -- 'approve_listing' | 'ban_user' | 'delete_cloudinary_file'
    target_type VARCHAR(50)   NULL,
    -- 'listing' | 'user' | 'payment' | 'cloudinary_file'
    target_id   BIGINT        NULL,
    detail      NVARCHAR(MAX) NULL,
    ip_address  VARCHAR(50)   NULL,
    created_at  DATETIME2     DEFAULT GETDATE()
);

CREATE TABLE DailyStats (
    stat_id              BIGINT        PRIMARY KEY IDENTITY(1,1),
    stat_date            DATE          NOT NULL UNIQUE,
    new_users            INT           DEFAULT 0,
    new_users_firebase   INT           DEFAULT 0,
    -- Riêng user đăng ký qua Firebase Social Login
    new_listings         INT           DEFAULT 0,
    total_revenue        DECIMAL(18,0) DEFAULT 0,
    total_searches       INT           DEFAULT 0,
    active_listings      INT           DEFAULT 0,

    -- ── FIREBASE FCM STATS (giữ nguyên) ──────────────────────
    fcm_sent_count    INT DEFAULT 0,
    fcm_failed_count  INT DEFAULT 0,
    -- ─────────────────────────────────────────────────────────

    -- ── CLOUDINARY STATS (thay thế Firebase Storage stats) ───
    cloudinary_upload_count  INT            DEFAULT 0,
    -- Số lượt upload lên Cloudinary trong ngày

    cloudinary_upload_mb     DECIMAL(10,2)  DEFAULT 0,
    -- Tổng dung lượng upload (MB) trong ngày
    -- Dùng để theo dõi usage Cloudinary (tránh vượt giới hạn)

    cloudinary_delete_count  INT            DEFAULT 0,
    -- Số file đã xóa khỏi Cloudinary trong ngày
    -- (Background Job xóa orphan files)
    -- ─────────────────────────────────────────────────────────

    created_at DATETIME2 DEFAULT GETDATE()
);

-- ============================================================
-- 14.1 SEED DATA - DU LIEU NEN BAT BUOC
-- ============================================================

INSERT INTO Roles (role_name, description) VALUES
    ('admin',    N'Quan tri vien he thong'),
    ('tenant',   N'Nguoi thue phong'),
    ('landlord', N'Chu nha / Nguoi cho thue');

INSERT INTO RoomTypes (type_name, sort_order) VALUES
    (N'Phong tro sinh vien',        1),
    (N'Can ho dich vu / Chung cu',  2),
    (N'O ghep (Roommate)',          3),
    (N'Nha nguyen can',             4);

INSERT INTO Amenities (name, category) VALUES
    (N'Wifi',               'basic'),
    (N'Dieu hoa',           'comfort'),
    (N'May giat',           'basic'),
    (N'Tu lanh',            'basic'),
    (N'Bep',                'basic'),
    (N'Bai xe',             'basic'),
    (N'Camera an ninh',     'security'),
    (N'Thang may',          'comfort'),
    (N'Ho boi',             'comfort'),
    (N'Gym',                'comfort'),
    (N'Ban cong',           'comfort'),
    (N'Noi that day du',    'comfort'),
    (N'Cua tu',             'security'),
    (N'Bao ve 24/7',        'security'),
    (N'Cho nuoi thu cung',  'basic');

-- Thu tu nay khop cac hang so trong ListingService:
-- active = 1, pending = 2, hidden = 5.
INSERT INTO ListingStatus (status_name) VALUES
    ('active'), ('pending'), ('rented'), ('rejected'), ('hidden');

INSERT INTO PaymentMethods (method_name) VALUES
    ('bank_transfer'), ('momo'), ('vnpay'), ('zalopay'), ('cash');

INSERT INTO PaymentStatus (status_name) VALUES
    ('pending'), ('success'), ('failed'), ('refunded');

INSERT INTO PostPackages
    (package_name, package_type, duration_days, price, priority,
     max_images, max_videos, allow_banner, badge_type, has_analytics, is_highlighted, description)
VALUES
(N'Thường',          'free',      30,       0,   0,  1, 0, 0, NULL,       0, 0, N'Hiển thị bình thường, 1 ảnh đăng kèm, không badge, không thống kê lượt xem'),
(N'VIP Tuần',        'vip',        7,   79000,   1,  5, 0, 0, 'vip',      1, 0, N'Ưu tiên hiển thị, tối đa 5 ảnh, badge VIP xanh, thống kê lượt xem'),
(N'VIP Tháng',       'vip',       30,  299000,   2, 10, 1, 0, 'vip',      1, 0, N'Ưu tiên cao, tối đa 10 ảnh, badge VIP xanh, 1 video đăng kèm, thống kê lượt xem'),
(N'Nổi bật 30 ngày', 'featured',  30,  499000,   3, 99, 3, 1, 'featured', 1, 1, N'Ưu tiên cao nhất, không giới hạn ảnh, badge nổi bật vàng, xuất hiện trên banner, 3 video đăng kèm, thống kê chi tiết');

GO

-- ============================================================
-- 15. STORED PROCEDURES
-- ============================================================

-- ── SP1: Firebase Auth (giữ nguyên logic, chỉ đổi comment) ──
CREATE OR ALTER PROCEDURE sp_UpsertFirebaseUser
    @firebase_uid    NVARCHAR(128),
    @email           NVARCHAR(150),
    @full_name       NVARCHAR(100),
    @avatar_url      NVARCHAR(500),
    -- URL từ Google/Facebook (không phải Cloudinary)
    -- Nếu user sau đó tự upload → cập nhật avatar_url = Cloudinary URL
    @provider        VARCHAR(30),
    @provider_uid    NVARCHAR(200),
    @access_token    NVARCHAR(MAX),
    @default_role_id INT = 2
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @user_id    BIGINT;
    DECLARE @is_new_user BIT = 0;

    -- Bước 1: Tìm user theo firebase_uid
    SELECT @user_id = user_id
    FROM Users
    WHERE firebase_uid = @firebase_uid;

    -- Bước 2: Nếu chưa có → Tạo mới
    IF @user_id IS NULL
    BEGIN
        -- Kiểm tra email có tồn tại chưa (merge account)
        SELECT @user_id = user_id
        FROM Users
        WHERE email = @email AND firebase_uid IS NULL;

        IF @user_id IS NOT NULL
        BEGIN
            -- Merge: Gán firebase_uid vào tài khoản cũ
            UPDATE Users SET
                firebase_uid      = @firebase_uid,
                firebase_provider = @provider,
                -- Chỉ cập nhật avatar nếu chưa có
                -- (Không ghi đè Cloudinary URL bằng Google URL)
                avatar_url        = ISNULL(avatar_url, @avatar_url),
                avatar_source     = CASE
                                        WHEN avatar_url IS NULL THEN @provider
                                        ELSE avatar_source
                                    END,
                is_verified       = 1,
                last_login        = GETDATE(),
                updated_at        = GETDATE()
            WHERE user_id = @user_id;
        END
        ELSE
        BEGIN
            -- Tạo tài khoản mới hoàn toàn
            INSERT INTO Users (
                full_name, email, firebase_uid, firebase_provider,
                avatar_url, avatar_source, role_id,
                is_verified, is_active
                -- avatar_public_id = NULL vì ảnh Google/Facebook
                -- không lưu trên Cloudinary
            )
            VALUES (
                @full_name, @email, @firebase_uid, @provider,
                @avatar_url, @provider, @default_role_id,
                1, 1
            );

            SET @user_id    = SCOPE_IDENTITY();
            SET @is_new_user = 1;

            INSERT INTO UserPreferences (user_id, onboarding_done)
            VALUES (@user_id, 0);
        END
    END
    ELSE
    BEGIN
        -- Bước 3: User đã có → Cập nhật last_login
        UPDATE Users SET
            last_login = GETDATE(),
            updated_at = GETDATE(),
            -- Chỉ cập nhật avatar nếu user chưa tự upload lên Cloudinary
            -- avatar_source = 'upload' nghĩa là đã có Cloudinary avatar
            avatar_url = CASE
                             WHEN avatar_source IN ('google', 'facebook', 'default')
                             THEN @avatar_url
                             ELSE avatar_url  -- Giữ nguyên Cloudinary URL
                         END
        WHERE user_id = @user_id;
    END

    -- Bước 4: Upsert SocialAuthProviders
    IF EXISTS (
        SELECT 1 FROM SocialAuthProviders
        WHERE provider = @provider AND provider_uid = @provider_uid
    )
    BEGIN
        UPDATE SocialAuthProviders SET
            access_token     = @access_token,
            firebase_uid     = @firebase_uid,
            token_expires_at = DATEADD(HOUR, 1, GETDATE()),
            updated_at       = GETDATE()
        WHERE provider = @provider AND provider_uid = @provider_uid;
    END
    ELSE
    BEGIN
        INSERT INTO SocialAuthProviders (
            user_id, provider, provider_uid,
            firebase_uid, access_token, token_expires_at
        )
        VALUES (
            @user_id, @provider, @provider_uid,
            @firebase_uid, @access_token,
            DATEADD(HOUR, 1, GETDATE())
        );
    END

    -- Bước 5: Trả về thông tin user
    SELECT
        u.user_id,
        u.full_name,
        u.email,
        u.phone,
        u.avatar_url,
        u.avatar_public_id,  -- Cloudinary public_id (NULL nếu ảnh Google/FB)
        u.firebase_uid,
        u.firebase_provider,
        u.avatar_source,
        u.role_id,
        r.role_name,
        u.is_verified,
        u.is_active,
        @is_new_user AS is_new_user,
        ISNULL(up.onboarding_done, 0) AS onboarding_done
    FROM Users u
    INNER JOIN Roles r ON u.role_id = r.role_id
    LEFT JOIN UserPreferences up ON u.user_id = up.user_id
    WHERE u.user_id = @user_id;
END
GO

-- ── SP2: Cập nhật Avatar Cloudinary ──────────────────────────
-- Gọi sau khi Flutter upload ảnh lên Cloudinary thành công
-- ASP.NET nhận public_id + secure_url từ Cloudinary response
CREATE OR ALTER PROCEDURE sp_UpdateUserAvatar
    @user_id     BIGINT,
    @public_id   NVARCHAR(300),
    -- Cloudinary Public ID mới
    -- VD: 'avatars/user_123/profile_v2'
    @secure_url  NVARCHAR(500),
    -- Cloudinary Secure URL mới
    @file_size_kb INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @old_public_id NVARCHAR(300);

    -- Lấy public_id cũ để xóa trên Cloudinary
    SELECT @old_public_id = avatar_public_id
    FROM Users
    WHERE user_id = @user_id;

    -- Cập nhật avatar mới
    UPDATE Users SET
        avatar_url       = @secure_url,
        avatar_public_id = @public_id,
        avatar_source    = 'upload',
        -- Đánh dấu là đã tự upload lên Cloudinary
        updated_at       = GETDATE()
    WHERE user_id = @user_id;

    -- Cập nhật CloudinaryFiles
    -- Đánh dấu file cũ là inactive (Background Job sẽ xóa)
    IF @old_public_id IS NOT NULL
    BEGIN
        UPDATE CloudinaryFiles SET
            is_active  = 0,
            deleted_at = GETDATE()
        WHERE public_id = @old_public_id;
    END

    -- Thêm file mới vào CloudinaryFiles
    INSERT INTO CloudinaryFiles (
        user_id, public_id, secure_url,
        resource_type, ref_type, ref_id,
        file_size_kb, folder, upload_status
    )
    VALUES (
        @user_id, @public_id, @secure_url,
        'image', 'avatar', @user_id,
        @file_size_kb,
        'avatars',  -- Tên folder Cloudinary
        'completed'
    );

    -- Trả về old_public_id để ASP.NET
    -- gọi Cloudinary API xóa ảnh cũ ngay lập tức (nếu muốn)
    -- hoặc để Background Job dọn sau
    SELECT @old_public_id AS old_public_id;
END
GO

-- ── SP3: Đăng ký file Cloudinary sau khi upload ──────────────
-- Flutter upload xong → ASP.NET gọi SP này để ghi nhận
-- Dùng cho ảnh listing, ảnh review, file chat...
CREATE OR ALTER PROCEDURE sp_RegisterCloudinaryFile
    @user_id      BIGINT,
    @public_id    NVARCHAR(300),
    @secure_url   NVARCHAR(500),
    @resource_type VARCHAR(10) = 'image',
    @format       VARCHAR(10)  = NULL,
    @width        INT          = NULL,
    @height       INT          = NULL,
    @duration_sec INT          = NULL,  -- Cho video
    @file_size_kb INT          = NULL,
    @folder       NVARCHAR(200) = NULL,
    @ref_type     VARCHAR(50)  = NULL,
    @ref_id       BIGINT       = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Tạo delivery_url với transformation tối ưu
    -- f_auto: tự chọn format tốt nhất (webp cho Chrome, jpg cho Safari)
    -- q_auto: tự điều chỉnh quality
    DECLARE @delivery_url NVARCHAR(500) = NULL;
    -- Lưu ý: delivery_url được tạo ở tầng application (ASP.NET)
    -- và truyền vào nếu cần. Ở đây để NULL, app tự build URL.

    INSERT INTO CloudinaryFiles (
        user_id, public_id, secure_url, delivery_url,
        resource_type, format,
        width, height, duration_sec, file_size_kb,
        folder, ref_type, ref_id,
        is_active, upload_status
    )
    VALUES (
        @user_id, @public_id, @secure_url, @delivery_url,
        @resource_type, @format,
        @width, @height, @duration_sec, @file_size_kb,
        @folder, @ref_type, @ref_id,
        1, 'completed'
    );

    SELECT SCOPE_IDENTITY() AS file_id;
END
GO

-- ── SP4: Xóa file Cloudinary (Soft Delete) ───────────────────
-- Đánh dấu file để Background Job xóa thật trên Cloudinary
CREATE OR ALTER PROCEDURE sp_SoftDeleteCloudinaryFile
    @public_id NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE CloudinaryFiles SET
        is_active  = 0,
        deleted_at = GETDATE()
    WHERE public_id = @public_id
      AND is_active = 1;

    -- Trả về số dòng bị ảnh hưởng
    SELECT @@ROWCOUNT AS affected_rows;
END
GO

-- ── SP5: Lấy file cần xóa trên Cloudinary (Background Job) ───
-- Chạy định kỳ (VD: mỗi giờ) để dọn file mồ côi
CREATE OR ALTER PROCEDURE sp_GetOrphanCloudinaryFiles
    @older_than_hours INT = 24
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        file_id,
        public_id,
        -- Public ID để gọi cloudinary.uploader.destroy()
        secure_url,
        resource_type,
        -- 'image' | 'video' | 'raw'
        -- Cần để gọi đúng API Cloudinary
        ref_type,
        ref_id,
        deleted_at
    FROM CloudinaryFiles
    WHERE is_active   = 0
      AND deleted_at  IS NOT NULL
      AND deleted_at  < DATEADD(HOUR, -@older_than_hours, GETDATE())
    ORDER BY deleted_at ASC;
    -- Xóa file cũ trước (FIFO)
END
GO

-- ── SP6: Xóa hoàn toàn record sau khi Cloudinary đã xóa ──────
-- Background Job gọi sau khi cloudinary.uploader.destroy() thành công
CREATE OR ALTER PROCEDURE sp_HardDeleteCloudinaryFile
    @public_id NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM CloudinaryFiles
    WHERE public_id = @public_id
      AND is_active = 0;

    SELECT @@ROWCOUNT AS deleted_rows;
END
GO

-- ── SP7: FCM - Cập nhật token (giữ nguyên) ───────────────────
CREATE OR ALTER PROCEDURE sp_UpdateFcmToken
    @user_id     BIGINT,
    @new_token   NVARCHAR(500),
    @device_type VARCHAR(10),
    @device_name NVARCHAR(100) = NULL,
    @old_token   NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @device_id BIGINT;

    IF @old_token IS NOT NULL
    BEGIN
        SELECT @device_id = device_id
        FROM UserDevices
        WHERE user_id = @user_id AND device_token = @old_token;
    END

    IF @device_id IS NOT NULL
    BEGIN
        UPDATE UserDevices SET
            device_token   = @new_token,
            device_name    = ISNULL(@device_name, device_name),
            is_active      = 1,
            fcm_last_error = NULL,
            fcm_error_at   = NULL,
            last_active    = GETDATE()
        WHERE device_id = @device_id;
    END
    ELSE
    BEGIN
        SELECT @device_id = device_id
        FROM UserDevices
        WHERE device_token = @new_token;

        IF @device_id IS NULL
        BEGIN
            INSERT INTO UserDevices (
                user_id, device_token, device_type,
                device_name, is_active
            )
            VALUES (
                @user_id, @new_token, @device_type,
                @device_name, 1
            );
            SET @device_id = SCOPE_IDENTITY();
        END
    END

    INSERT INTO FirebaseTokenLogs (
        user_id, device_id, old_token,
        new_token, change_reason, device_type
    )
    VALUES (
        @user_id, @device_id, @old_token,
        @new_token,
        CASE WHEN @old_token IS NULL THEN 'first_login' ELSE 'token_refresh' END,
        @device_type
    );

    SELECT @device_id AS device_id;
END
GO

-- ── SP8: FCM - Đánh dấu token hết hạn (giữ nguyên) ──────────
CREATE OR ALTER PROCEDURE sp_InvalidateFcmToken
    @device_token  NVARCHAR(500),
    @error_message NVARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE UserDevices SET
        is_active      = 0,
        fcm_last_error = @error_message,
        fcm_error_at   = GETDATE()
    WHERE device_token = @device_token;
END
GO

-- ── SP9: FCM - Lấy token hợp lệ để gửi notification ─────────
CREATE OR ALTER PROCEDURE sp_GetActiveFcmTokens
    @user_id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        device_id,
        device_token,
        device_type,
        device_name
    FROM UserDevices
    WHERE user_id      = @user_id
      AND is_active    = 1
      AND fcm_last_error IS NULL
    ORDER BY last_active DESC;
END
GO

-- ── SP10: FCM - Ghi nhận kết quả gửi notification ────────────
CREATE OR ALTER PROCEDURE sp_UpdateNotificationFcmStatus
    @notif_id   BIGINT,
    @fcm_status VARCHAR(20),
    @error_msg  NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE Notifications SET
        fcm_status    = @fcm_status,
        fcm_sent_at   = CASE WHEN @fcm_status = 'sent' THEN GETDATE() ELSE NULL END,
        fcm_error_msg = @error_msg
    WHERE notif_id = @notif_id;
END
GO

-- ── SP11: Thống kê dung lượng Cloudinary theo user ───────────
CREATE OR ALTER PROCEDURE sp_GetUserCloudinaryUsage
    @user_id BIGINT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        resource_type,
        ref_type,
        COUNT(*)                    AS file_count,
        SUM(file_size_kb)           AS total_size_kb,
        SUM(file_size_kb) / 1024.0  AS total_size_mb
    FROM CloudinaryFiles
    WHERE user_id = @user_id
      AND is_active = 1
    GROUP BY resource_type, ref_type
    ORDER BY total_size_kb DESC;
END
GO

-- ============================================================
-- 16. VIEWS
-- ============================================================

-- View: Thông tin user kèm Firebase + Cloudinary
CREATE OR ALTER VIEW vw_UserInfo AS
SELECT
    u.user_id,
    u.full_name,
    u.email,
    u.phone,
    u.avatar_url,
    u.avatar_public_id,     -- Cloudinary public_id (NULL nếu ảnh Google/FB)
    u.avatar_source,        -- 'upload' | 'google' | 'facebook' | 'default'
    u.firebase_uid,
    u.firebase_provider,
    u.is_verified,
    u.is_active,
    r.role_name,
    -- Phương thức xác thực
    CASE
        WHEN u.firebase_uid IS NOT NULL AND u.password_hash IS NOT NULL
            THEN 'hybrid'
        WHEN u.firebase_uid IS NOT NULL
            THEN 'firebase_only'
        ELSE 'password_only'
    END AS auth_method,
    -- Số thiết bị FCM đang active
    (SELECT COUNT(*) FROM UserDevices ud
     WHERE ud.user_id = u.user_id AND ud.is_active = 1) AS active_devices,
    -- Tổng dung lượng Cloudinary (KB)
    (SELECT ISNULL(SUM(cf.file_size_kb), 0)
     FROM CloudinaryFiles cf
     WHERE cf.user_id = u.user_id AND cf.is_active = 1) AS cloudinary_usage_kb
FROM Users u
INNER JOIN Roles r ON u.role_id = r.role_id;
GO

-- View: Tin đăng kèm gói VIP và ảnh Cloudinary
-- View tuong thich voi backend Admin hien tai.
CREATE OR ALTER VIEW vw_UserFirebaseInfo AS
SELECT
    user_id,
    full_name,
    email,
    phone,
    firebase_uid,
    firebase_provider,
    avatar_url,
    avatar_source,
    is_verified,
    is_active,
    role_name,
    active_devices,
    CASE WHEN firebase_uid IS NOT NULL THEN 1 ELSE 0 END AS uses_firebase,
    auth_method
FROM vw_UserInfo;
GO

CREATE OR ALTER VIEW vw_ListingWithPackage AS
SELECT
    l.listing_id,
    l.title,
    l.price,
    l.area,
    l.street_address,
    l.latitude,
    l.longitude,
    l.image_0 AS cover_image,      -- Cloudinary URL ảnh bìa
    l.cloudinary_folder,           -- Thư mục Cloudinary chứa tất cả file
    l.view_count,
    l.save_count,
    ls.status_name,
    -- Gói VIP hiện tại
    pp.package_name,
    pp.package_type,
    pp.badge_type,
    pp.is_highlighted,
    pp.allow_banner,
    pp.max_images,
    pp.max_videos,
    pp.has_analytics,
    lpp.end_date AS package_expires_at,
    DATEDIFF(DAY, GETDATE(), lpp.end_date) AS package_days_left,
    -- Số ảnh đã upload (so với giới hạn gói)
    (SELECT COUNT(*) FROM ListingImages li
     WHERE li.listing_id = l.listing_id) AS uploaded_images,
    -- Số video đã upload
    (SELECT COUNT(*) FROM ListingVideos lv
     WHERE lv.listing_id = l.listing_id) AS uploaded_videos,
    -- Chủ nhà
    u.full_name    AS landlord_name,
    u.phone        AS landlord_phone,
    u.firebase_uid AS landlord_firebase_uid
FROM Listings l
INNER JOIN ListingStatus ls ON l.status_id = ls.status_id
INNER JOIN Users u          ON l.landlord_id = u.user_id
LEFT JOIN ListingPostPackages lpp
    ON l.listing_id = lpp.listing_id AND lpp.is_active = 1
LEFT JOIN PostPackages pp ON lpp.package_id = pp.package_id;
GO

-- View: FCM Notification chưa gửi (Background Job polling)
CREATE OR ALTER VIEW vw_PendingFcmNotifications AS
SELECT
    n.notif_id,
    n.user_id,
    n.title,
    n.body,
    n.notif_type,
    n.ref_id,
    n.ref_type,
    n.sent_at,
    ud.device_token,
    ud.device_type,
    ud.device_id
FROM Notifications n
INNER JOIN UserDevices ud
    ON n.user_id = ud.user_id AND ud.is_active = 1
WHERE n.fcm_status = 'pending'
  AND n.sent_at > DATEADD(HOUR, -24, GETDATE());
GO

-- View: File Cloudinary cần dọn (Background Job)
CREATE OR ALTER VIEW vw_OrphanCloudinaryFiles AS
SELECT
    file_id,
    public_id,
    resource_type,
    file_size_kb,
    ref_type,
    ref_id,
    deleted_at,
    -- Số giờ đã chờ xóa
    DATEDIFF(HOUR, deleted_at, GETDATE()) AS hours_since_deleted
FROM CloudinaryFiles
WHERE is_active  = 0
  AND deleted_at IS NOT NULL
  AND deleted_at < DATEADD(HOUR, -24, GETDATE())
-- Chờ 24h trước khi xóa thật
-- Phòng trường hợp cần rollback
ORDER BY deleted_at ASC
OFFSET 0 ROWS;
GO

PRINT N'✅ Database PhongTroDB v1.3 - Cloudinary Integration!';
PRINT N'';
PRINT N'📦 FILE STORAGE: Firebase Storage → Cloudinary';
PRINT N'   - Bảng mới : CloudinaryFiles (thay FirebaseStorageFiles)';
PRINT N'   - Cột mới  : cloudinary_public_id (thay storage_path)';
PRINT N'   - Cột mới  : cloudinary_folder (thay storage_folder)';
PRINT N'   - Cột mới  : Users.avatar_public_id';
PRINT N'   - Cột mới  : ListingImages.cloudinary_public_id, width, height, format';
PRINT N'   - Cột mới  : ListingVideos.cloudinary_public_id, duration_sec';
PRINT N'   - Cột mới  : ReviewImages.cloudinary_public_id';
PRINT N'   - Cột mới  : Messages.cloudinary_public_id';
PRINT N'   - Cột mới  : Banners.cloudinary_public_id';
PRINT N'';
PRINT N'🔥 FIREBASE AUTH + FCM: Giữ nguyên';
PRINT N'   - firebase_uid, firebase_provider';
PRINT N'   - UserDevices, FirebaseTokenLogs';
PRINT N'   - Notifications.fcm_status';
PRINT N'';
PRINT N'⚙️  STORED PROCEDURES:';
PRINT N'   - sp_UpsertFirebaseUser (cập nhật logic avatar)';
PRINT N'   - sp_UpdateUserAvatar (Cloudinary)';
PRINT N'   - sp_RegisterCloudinaryFile';
PRINT N'   - sp_SoftDeleteCloudinaryFile';
PRINT N'   - sp_GetOrphanCloudinaryFiles';
PRINT N'   - sp_HardDeleteCloudinaryFile';
PRINT N'   - sp_GetUserCloudinaryUsage';
PRINT N'   - sp_UpdateFcmToken, sp_InvalidateFcmToken';
PRINT N'   - sp_GetActiveFcmTokens';
PRINT N'   - sp_UpdateNotificationFcmStatus';
PRINT N'';
PRINT N'👁️  VIEWS:';
PRINT N'   - vw_UserInfo';
PRINT N'   - vw_UserFirebaseInfo';
PRINT N'   - vw_ListingWithPackage';
PRINT N'   - vw_PendingFcmNotifications';
PRINT N'   - vw_OrphanCloudinaryFiles';
GO
