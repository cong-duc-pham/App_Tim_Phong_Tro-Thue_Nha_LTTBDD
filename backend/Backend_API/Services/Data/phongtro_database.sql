-- ============================================================
--  PHÒNG TRỌ APP - SQL SERVER DATABASE SCHEMA
--  Phiên bản : 1.1
--  Ngày cập nhật : 2026-03-20
--  Thay đổi  : Lược bỏ Hợp đồng thuê nhà (Contracts, ContractStatus,
--              UtilityReadings), tách Invoices độc lập chỉ phục vụ
--              thanh toán gói VIP, cập nhật PostPackages thêm 6 cột
--              phân biệt quyền lợi từng gói
-- ============================================================

USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'PhongTroDB')
    DROP DATABASE PhongTroDB;
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
    role_id      INT           PRIMARY KEY IDENTITY(1,1), -- Mã vai trò (tự tăng)
    role_name    NVARCHAR(50)  NOT NULL UNIQUE,            -- Tên vai trò: 'tenant' | 'landlord' | 'admin'
    description  NVARCHAR(255) NULL,                      -- Mô tả chi tiết vai trò
    created_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm tạo vai trò
);

CREATE TABLE Users (
    user_id          BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã người dùng (tự tăng)
    full_name        NVARCHAR(100) NOT NULL,                   -- Họ và tên đầy đủ
    email            NVARCHAR(150) NULL UNIQUE,                -- Địa chỉ email (NULL nếu đăng ký bằng SĐT)
    phone            VARCHAR(15)   NULL UNIQUE,                -- Số điện thoại (NULL nếu đăng ký bằng email)
    password_hash    NVARCHAR(255) NULL,                       -- Mật khẩu đã mã hóa (NULL nếu đăng nhập mạng xã hội)
    avatar_url       NVARCHAR(500) NULL,                       -- Đường dẫn ảnh đại diện
    date_of_birth    DATE          NULL,                       -- Ngày sinh
    gender           TINYINT       NULL,                       -- Giới tính: 0 = Nam | 1 = Nữ | 2 = Khác
    role_id          INT           NOT NULL REFERENCES Roles(role_id), -- Vai trò của người dùng
    is_verified      BIT           DEFAULT 0,                  -- Tài khoản đã xác thực: 0 = Chưa | 1 = Đã xác thực
    is_active        BIT           DEFAULT 1,                  -- Trạng thái tài khoản: 1 = Hoạt động | 0 = Bị khóa
    last_login       DATETIME2     NULL,                       -- Thời điểm đăng nhập gần nhất
    created_at       DATETIME2     DEFAULT GETDATE(),          -- Thời điểm tạo tài khoản
    updated_at       DATETIME2     DEFAULT GETDATE()           -- Thời điểm cập nhật thông tin gần nhất
);

CREATE TABLE SocialAuthProviders (
    provider_id   BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã bản ghi liên kết mạng xã hội (tự tăng)
    user_id       BIGINT        NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, -- Người dùng được liên kết
    provider      VARCHAR(20)   NOT NULL,                  -- Nhà cung cấp: 'google' | 'facebook'
    provider_uid  NVARCHAR(200) NOT NULL,                  -- ID người dùng do nhà cung cấp cấp
    access_token  NVARCHAR(MAX) NULL,                      -- Token truy cập từ nhà cung cấp (dùng để gọi API)
    created_at    DATETIME2     DEFAULT GETDATE(),         -- Thời điểm liên kết tài khoản mạng xã hội
    UNIQUE (provider, provider_uid)
);

CREATE TABLE OtpCodes (
    otp_id      BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã bản ghi OTP (tự tăng)
    user_id     BIGINT        NULL REFERENCES Users(user_id), -- Người dùng yêu cầu OTP (NULL nếu chưa có tài khoản)
    contact     NVARCHAR(150) NOT NULL,                   -- Email hoặc số điện thoại nhận mã OTP
    otp_type    VARCHAR(20)   NOT NULL,                   -- Mục đích: 'register' | 'forgot_password' | 'verify'
    code        VARCHAR(10)   NOT NULL,                   -- Mã OTP gửi đến người dùng
    is_used     BIT           DEFAULT 0,                  -- Trạng thái dùng: 0 = Chưa dùng | 1 = Đã dùng
    expires_at  DATETIME2     NOT NULL,                   -- Thời điểm hết hạn mã OTP
    created_at  DATETIME2     DEFAULT GETDATE()           -- Thời điểm tạo mã OTP
);

CREATE TABLE UserDevices (
    device_id     BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã thiết bị (tự tăng)
    user_id       BIGINT        NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, -- Chủ sở hữu thiết bị
    device_token  NVARCHAR(500) NOT NULL,                  -- FCM Token dùng để gửi push notification
    device_type   VARCHAR(10)   NOT NULL,                  -- Loại thiết bị: 'ios' | 'android' | 'web'
    device_name   NVARCHAR(100) NULL,                      -- Tên thiết bị (VD: "iPhone 14 Pro", "Samsung S24")
    is_active     BIT           DEFAULT 1,                 -- Trạng thái: 1 = Đang sử dụng | 0 = Không dùng nữa
    last_active   DATETIME2     DEFAULT GETDATE(),         -- Thời điểm thiết bị hoạt động gần nhất
    created_at    DATETIME2     DEFAULT GETDATE()          -- Thời điểm đăng ký thiết bị lần đầu
);

-- ============================================================
-- 2. ONBOARDING & USER PREFERENCES - CÀI ĐẶT NHU CẦU
-- ============================================================

CREATE TABLE RoomTypes (
    type_id      INT           PRIMARY KEY IDENTITY(1,1), -- Mã loại phòng (tự tăng)
    type_name    NVARCHAR(100) NOT NULL UNIQUE,            -- Tên loại phòng (VD: 'Phòng trọ sinh viên')
    icon_url     NVARCHAR(500) NULL,                       -- Đường dẫn icon hiển thị trên ứng dụng
    sort_order   INT           DEFAULT 0,                  -- Thứ tự hiển thị trong danh mục
    is_active    BIT           DEFAULT 1                   -- Trạng thái: 1 = Hiển thị | 0 = Ẩn
);

CREATE TABLE Amenities (
    amenity_id   INT           PRIMARY KEY IDENTITY(1,1), -- Mã tiện ích (tự tăng)
    name         NVARCHAR(100) NOT NULL UNIQUE,            -- Tên tiện ích (VD: 'Wifi', 'Điều hòa', 'Máy giặt')
    icon_url     NVARCHAR(500) NULL,                       -- Đường dẫn icon tiện ích
    category     NVARCHAR(50)  NULL,                       -- Nhóm tiện ích: 'basic' | 'security' | 'comfort'
    is_active    BIT           DEFAULT 1                   -- Trạng thái: 1 = Đang dùng | 0 = Ẩn
);

CREATE TABLE UserPreferences (
    pref_id          BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã cài đặt nhu cầu (tự tăng)
    user_id          BIGINT        NOT NULL UNIQUE REFERENCES Users(user_id) ON DELETE CASCADE, -- Người dùng (1 người - 1 bộ cài đặt)
    preferred_area   NVARCHAR(200) NULL,                       -- Khu vực mong muốn (tên quận/huyện/trường đại học)
    min_price        DECIMAL(15,0) NULL,                       -- Giá thuê tối thiểu mong muốn (VNĐ/tháng)
    max_price        DECIMAL(15,0) NULL,                       -- Giá thuê tối đa mong muốn (VNĐ/tháng)
    allow_pet        BIT           NULL,                       -- Muốn phòng cho nuôi thú cưng: 1 = Có | 0 = Không
    latitude         FLOAT         NULL,                       -- Vĩ độ vị trí GPS của người dùng (từ onboarding)
    longitude        FLOAT         NULL,                       -- Kinh độ vị trí GPS của người dùng (từ onboarding)
    search_radius_km INT           NULL DEFAULT 5,             -- Bán kính tìm kiếm xung quanh vị trí (km)
    onboarding_done  BIT           DEFAULT 0,                  -- Đã hoàn thành onboarding: 0 = Chưa | 1 = Hoàn thành
    created_at       DATETIME2     DEFAULT GETDATE(),          -- Thời điểm tạo cài đặt
    updated_at       DATETIME2     DEFAULT GETDATE()           -- Thời điểm cập nhật cài đặt gần nhất
);

CREATE TABLE UserPreferenceRoomTypes (
    id         BIGINT PRIMARY KEY IDENTITY(1,1),               -- Mã bản ghi (tự tăng)
    pref_id    BIGINT NOT NULL REFERENCES UserPreferences(pref_id) ON DELETE CASCADE, -- Cài đặt nhu cầu liên kết
    type_id    INT    NOT NULL REFERENCES RoomTypes(type_id),  -- Loại phòng người dùng quan tâm
    UNIQUE (pref_id, type_id)
);

CREATE TABLE UserPreferenceAmenities (
    id          BIGINT PRIMARY KEY IDENTITY(1,1),              -- Mã bản ghi (tự tăng)
    pref_id     BIGINT NOT NULL REFERENCES UserPreferences(pref_id) ON DELETE CASCADE, -- Cài đặt nhu cầu liên kết
    amenity_id  INT    NOT NULL REFERENCES Amenities(amenity_id), -- Tiện ích người dùng mong muốn có
    UNIQUE (pref_id, amenity_id)
);

-- ============================================================
-- 3. ĐỊA LÝ - TỈNH / QUẬN / PHƯỜNG
-- ============================================================

CREATE TABLE Provinces (
    province_id    INT           PRIMARY KEY IDENTITY(1,1), -- Mã tỉnh/thành phố (tự tăng)
    province_name  NVARCHAR(100) NOT NULL,                   -- Tên tỉnh/thành phố (VD: 'TP. Hồ Chí Minh')
    province_code  VARCHAR(10)   NULL UNIQUE                 -- Mã hành chính tỉnh/thành phố
);

CREATE TABLE Districts (
    district_id    INT           PRIMARY KEY IDENTITY(1,1), -- Mã quận/huyện (tự tăng)
    province_id    INT           NOT NULL REFERENCES Provinces(province_id), -- Thuộc tỉnh/thành phố nào
    district_name  NVARCHAR(100) NOT NULL,                   -- Tên quận/huyện (VD: 'Quận 1', 'Bình Thạnh')
    district_code  VARCHAR(10)   NULL                        -- Mã hành chính quận/huyện
);

CREATE TABLE Wards (
    ward_id       INT           PRIMARY KEY IDENTITY(1,1),  -- Mã phường/xã (tự tăng)
    district_id   INT           NOT NULL REFERENCES Districts(district_id), -- Thuộc quận/huyện nào
    ward_name     NVARCHAR(100) NOT NULL,                    -- Tên phường/xã (VD: 'Phường Bến Nghé')
    ward_code     VARCHAR(10)   NULL                         -- Mã hành chính phường/xã
);

-- ============================================================
-- 4. LISTINGS - TIN ĐĂNG PHÒNG
-- ============================================================

CREATE TABLE ListingStatus (
    status_id    INT          PRIMARY KEY IDENTITY(1,1), -- Mã trạng thái tin đăng (tự tăng)
    status_name  VARCHAR(30)  NOT NULL UNIQUE             -- Trạng thái: 'active'|'rented'|'hidden'|'pending'|'rejected'
);

CREATE TABLE Listings (
    listing_id       BIGINT          PRIMARY KEY IDENTITY(1,1), -- Mã tin đăng (tự tăng)
    landlord_id      BIGINT          NOT NULL REFERENCES Users(user_id),          -- Chủ nhà đăng tin
    type_id          INT             NOT NULL REFERENCES RoomTypes(type_id),       -- Loại hình phòng
    status_id        INT             NOT NULL REFERENCES ListingStatus(status_id), -- Trạng thái tin đăng
    title            NVARCHAR(200)   NOT NULL,               -- Tiêu đề tin đăng
    description      NVARCHAR(MAX)   NULL,                   -- Mô tả chi tiết phòng
    price            DECIMAL(15,0)   NOT NULL,               -- Giá thuê mỗi tháng (VNĐ)
    area             DECIMAL(8,2)    NOT NULL,               -- Diện tích phòng (m²)
    floor            INT             NULL,                   -- Tầng của phòng trong tòa nhà
    total_floors     INT             NULL,                   -- Tổng số tầng của tòa nhà
    max_occupants    INT             NULL DEFAULT 1,         -- Số người tối đa được phép ở
    -- Địa chỉ chi tiết
    province_id      INT             NULL REFERENCES Provinces(province_id), -- Tỉnh/Thành phố
    district_id      INT             NULL REFERENCES Districts(district_id), -- Quận/Huyện
    ward_id          INT             NULL REFERENCES Wards(ward_id),         -- Phường/Xã
    street_address   NVARCHAR(300)   NOT NULL,               -- Địa chỉ chi tiết (số nhà, tên đường)
    latitude         FLOAT           NULL,                   -- Vĩ độ tọa độ GPS của phòng
    longitude        FLOAT           NULL,                   -- Kinh độ tọa độ GPS của phòng
    -- Trạng thái & nhãn đặc biệt
    is_verified      BIT             DEFAULT 0,              -- Tin đã được admin xác thực: 0 = Chưa | 1 = Đã xác thực
    is_featured      BIT             DEFAULT 0,              -- Tin VIP / Nổi bật: 0 = Thường | 1 = Nổi bật
    is_new           BIT             DEFAULT 1,              -- Nhãn tin mới: 1 = Mới đăng | 0 = Cũ
    allow_pet        BIT             DEFAULT 0,              -- Cho phép nuôi thú cưng: 0 = Không | 1 = Có
    -- Chi phí dịch vụ hàng tháng
    electric_price   DECIMAL(10,0)   NULL,                   -- Đơn giá điện (VNĐ/kWh)
    water_price      DECIMAL(10,0)   NULL,                   -- Đơn giá nước (VNĐ/m³)
    internet_price   DECIMAL(10,0)   NULL,                   -- Phí internet cố định (VNĐ/tháng)
    parking_price    DECIMAL(10,0)   NULL,                   -- Phí gửi xe (VNĐ/tháng)
    -- Thống kê tương tác
    view_count       INT             DEFAULT 0,              -- Tổng số lượt xem tin đăng
    save_count       INT             DEFAULT 0,              -- Tổng số lượt lưu / yêu thích
    -- Thời hạn tin đăng
    available_from   DATE            NULL,                   -- Ngày có thể vào ở sớm nhất
    expired_at       DATETIME2       NULL,                   -- Thời điểm tin đăng hết hạn hiển thị
    created_at       DATETIME2       DEFAULT GETDATE(),      -- Thời điểm đăng tin lần đầu
    updated_at       DATETIME2       DEFAULT GETDATE()       -- Thời điểm chỉnh sửa tin gần nhất
);

CREATE INDEX IX_Listings_LatLng   ON Listings (latitude, longitude);  -- Index tìm kiếm gần vị trí GPS
CREATE INDEX IX_Listings_Price    ON Listings (price);                 -- Index lọc theo khoảng giá
CREATE INDEX IX_Listings_District ON Listings (district_id);           -- Index lọc theo quận/huyện
CREATE INDEX IX_Listings_Status   ON Listings (status_id);             -- Index lọc theo trạng thái tin
CREATE INDEX IX_Listings_Landlord ON Listings (landlord_id);           -- Index tra cứu tin của chủ nhà

CREATE TABLE ListingAmenities (
    id          BIGINT PRIMARY KEY IDENTITY(1,1),              -- Mã bản ghi (tự tăng)
    listing_id  BIGINT NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng sở hữu tiện ích
    amenity_id  INT    NOT NULL REFERENCES Amenities(amenity_id), -- Tiện ích có trong phòng
    UNIQUE (listing_id, amenity_id)
);

CREATE TABLE ListingImages (
    image_id     BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã ảnh (tự tăng)
    listing_id   BIGINT        NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng chứa ảnh
    image_url    NVARCHAR(500) NOT NULL,                   -- Đường dẫn URL ảnh
    is_cover     BIT           DEFAULT 0,                  -- Ảnh đại diện (thumbnail chính): 0 = Không | 1 = Có
    sort_order   INT           DEFAULT 0,                  -- Thứ tự hiển thị trong bộ ảnh
    created_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm tải ảnh lên
);

CREATE TABLE ListingVideos (
    video_id     BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã video (tự tăng)
    listing_id   BIGINT        NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng chứa video
    video_url    NVARCHAR(500) NOT NULL,                   -- Đường dẫn URL video
    thumbnail    NVARCHAR(500) NULL,                       -- Ảnh thumbnail đại diện cho video
    created_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm tải video lên
);

CREATE TABLE ListingPriceHistory (
    history_id   BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã lịch sử thay đổi giá (tự tăng)
    listing_id   BIGINT        NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng liên quan
    old_price    DECIMAL(15,0) NOT NULL,                   -- Giá thuê cũ trước khi thay đổi (VNĐ/tháng)
    new_price    DECIMAL(15,0) NOT NULL,                   -- Giá thuê mới sau khi thay đổi (VNĐ/tháng)
    changed_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm cập nhật giá
);

-- ============================================================
-- 5. BANNER & GỢI Ý TRANG CHỦ
-- ============================================================

CREATE TABLE Banners (
    banner_id    INT           PRIMARY KEY IDENTITY(1,1), -- Mã banner (tự tăng)
    title        NVARCHAR(200) NULL,                       -- Tiêu đề hiển thị trên banner
    image_url    NVARCHAR(500) NOT NULL,                   -- Đường dẫn URL ảnh banner
    link_url     NVARCHAR(500) NULL,                       -- URL điều hướng khi người dùng bấm vào banner
    listing_id   BIGINT        NULL REFERENCES Listings(listing_id), -- Tin đăng liên kết trực tiếp (nếu có)
    sort_order   INT           DEFAULT 0,                  -- Thứ tự hiển thị trong slider banner
    is_active    BIT           DEFAULT 1,                  -- Trạng thái banner: 1 = Hiển thị | 0 = Ẩn
    start_date   DATETIME2     NULL,                       -- Thời điểm bắt đầu chiến dịch banner
    end_date     DATETIME2     NULL,                       -- Thời điểm kết thúc chiến dịch banner
    created_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm tạo banner
);

-- ============================================================
-- 6. TÌM KIẾM & YÊU THÍCH
-- ============================================================

CREATE TABLE SearchHistory (
    search_id    BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã lịch sử tìm kiếm (tự tăng)
    user_id      BIGINT        NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, -- Người dùng thực hiện tìm kiếm
    keyword      NVARCHAR(300) NOT NULL,                   -- Từ khóa nhập vào (tên đường, quận, trường đại học,...)
    filter_json  NVARCHAR(MAX) NULL,                       -- Bộ lọc đã áp dụng lưu dạng JSON (loại phòng, giá, tiện ích,...)
    result_count INT           NULL,                       -- Số lượng kết quả trả về
    searched_at  DATETIME2     DEFAULT GETDATE()           -- Thời điểm thực hiện tìm kiếm
);

CREATE TABLE ViewHistory (
    view_id      BIGINT    PRIMARY KEY IDENTITY(1,1),     -- Mã lượt xem (tự tăng)
    user_id      BIGINT    NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,       -- Người dùng đã xem tin
    listing_id   BIGINT    NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng được xem
    viewed_at    DATETIME2 DEFAULT GETDATE(),              -- Thời điểm xem tin đăng
    duration_sec INT       NULL                            -- Thời gian xem trang (giây) - dùng cho thuật toán gợi ý
);

CREATE INDEX IX_ViewHistory_User ON ViewHistory (user_id, viewed_at DESC); -- Index lấy lịch sử xem gần nhất theo người dùng

CREATE TABLE Favorites (
    favorite_id  BIGINT    PRIMARY KEY IDENTITY(1,1),     -- Mã yêu thích (tự tăng)
    user_id      BIGINT    NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE,       -- Người dùng lưu yêu thích
    listing_id   BIGINT    NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng được lưu vào danh sách yêu thích
    created_at   DATETIME2 DEFAULT GETDATE(),              -- Thời điểm lưu tin vào danh sách yêu thích
    UNIQUE (user_id, listing_id)
);

-- ============================================================
-- 7. TIN NHẮN - CHAT
-- ============================================================

CREATE TABLE Conversations (
    conv_id       BIGINT    PRIMARY KEY IDENTITY(1,1),    -- Mã cuộc hội thoại (tự tăng)
    listing_id    BIGINT    NULL REFERENCES Listings(listing_id), -- Tin đăng được hỏi (NULL nếu chat ngoài tin đăng)
    tenant_id     BIGINT    NOT NULL REFERENCES Users(user_id),   -- Người thuê trong cuộc hội thoại
    landlord_id   BIGINT    NOT NULL REFERENCES Users(user_id),   -- Chủ nhà trong cuộc hội thoại
    last_msg_at   DATETIME2 NULL,                          -- Thời điểm tin nhắn cuối (dùng để sắp xếp danh sách chat)
    created_at    DATETIME2 DEFAULT GETDATE(),             -- Thời điểm bắt đầu cuộc hội thoại
    UNIQUE (listing_id, tenant_id, landlord_id)
);

CREATE TABLE Messages (
    message_id    BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã tin nhắn (tự tăng)
    conv_id       BIGINT        NOT NULL REFERENCES Conversations(conv_id) ON DELETE CASCADE, -- Cuộc hội thoại chứa tin nhắn
    sender_id     BIGINT        NOT NULL REFERENCES Users(user_id), -- Người gửi tin nhắn
    content       NVARCHAR(MAX) NULL,                       -- Nội dung tin nhắn văn bản (NULL nếu chỉ gửi ảnh/file)
    msg_type      VARCHAR(20)   DEFAULT 'text',             -- Loại tin nhắn: 'text' | 'image' | 'file' | 'system'
    file_url      NVARCHAR(500) NULL,                       -- Đường dẫn ảnh hoặc file đính kèm
    is_read       BIT           DEFAULT 0,                  -- Trạng thái đọc: 0 = Chưa đọc | 1 = Đã đọc
    sent_at       DATETIME2     DEFAULT GETDATE()           -- Thời điểm gửi tin nhắn
);

CREATE INDEX IX_Messages_Conv ON Messages (conv_id, sent_at DESC); -- Index tải tin nhắn mới nhất theo cuộc hội thoại

-- ============================================================
-- 8. THÔNG BÁO - NOTIFICATIONS
-- ============================================================

CREATE TABLE Notifications (
    notif_id      BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã thông báo (tự tăng)
    user_id       BIGINT        NOT NULL REFERENCES Users(user_id) ON DELETE CASCADE, -- Người dùng nhận thông báo
    title         NVARCHAR(200) NOT NULL,                   -- Tiêu đề thông báo
    body          NVARCHAR(MAX) NULL,                       -- Nội dung chi tiết thông báo
    notif_type    VARCHAR(50)   NULL,                       -- Loại thông báo: 'new_message' | 'listing_match' | 'payment' | 'system'
    ref_id        BIGINT        NULL,                       -- ID đối tượng liên quan (tin đăng, thanh toán,...)
    ref_type      VARCHAR(50)   NULL,                       -- Loại đối tượng liên quan: 'listing' | 'payment'
    is_read       BIT           DEFAULT 0,                  -- Trạng thái đọc: 0 = Chưa đọc | 1 = Đã đọc
    sent_at       DATETIME2     DEFAULT GETDATE()           -- Thời điểm gửi thông báo
);

CREATE INDEX IX_Notifications_User ON Notifications (user_id, is_read, sent_at DESC); -- Index lấy thông báo chưa đọc

-- ============================================================
-- 9. ĐÁNH GIÁ & REVIEW PHÒNG
-- ============================================================

CREATE TABLE Reviews (
    review_id          BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã đánh giá (tự tăng)
    listing_id         BIGINT        NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng được đánh giá
    reviewer_id        BIGINT        NOT NULL REFERENCES Users(user_id), -- Người viết đánh giá (người thuê)
    rating             TINYINT       NOT NULL CHECK (rating BETWEEN 1 AND 5),              -- Điểm tổng thể (1-5 sao)
    comment            NVARCHAR(MAX) NULL,                       -- Nhận xét chi tiết bằng văn bản
    -- Điểm đánh giá theo từng tiêu chí
    rating_location    TINYINT       NULL CHECK (rating_location  BETWEEN 1 AND 5),        -- Điểm vị trí / thuận tiện di chuyển (1-5 sao)
    rating_price       TINYINT       NULL CHECK (rating_price     BETWEEN 1 AND 5),        -- Điểm giá cả / tương xứng giá trị (1-5 sao)
    rating_cleanness   TINYINT       NULL CHECK (rating_cleanness BETWEEN 1 AND 5),        -- Điểm vệ sinh / sạch sẽ (1-5 sao)
    rating_security    TINYINT       NULL CHECK (rating_security  BETWEEN 1 AND 5),        -- Điểm an ninh / an toàn (1-5 sao)
    is_approved        BIT           DEFAULT 0,                  -- Admin duyệt hiển thị: 0 = Chờ duyệt | 1 = Đã duyệt
    landlord_reply     NVARCHAR(MAX) NULL,                       -- Phản hồi của chủ nhà đối với đánh giá
    replied_at         DATETIME2     NULL,                       -- Thời điểm chủ nhà gửi phản hồi
    created_at         DATETIME2     DEFAULT GETDATE(),          -- Thời điểm người dùng gửi đánh giá
    updated_at         DATETIME2     DEFAULT GETDATE(),          -- Thời điểm chỉnh sửa đánh giá gần nhất
    UNIQUE (listing_id, reviewer_id)                             -- Mỗi người chỉ đánh giá 1 lần cho 1 phòng
);

CREATE TABLE ReviewImages (
    img_id       BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã ảnh trong đánh giá (tự tăng)
    review_id    BIGINT        NOT NULL REFERENCES Reviews(review_id) ON DELETE CASCADE, -- Đánh giá chứa ảnh
    image_url    NVARCHAR(500) NOT NULL,                   -- Đường dẫn URL ảnh kèm theo đánh giá
    created_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm tải ảnh đánh giá lên
);

-- ============================================================
-- 10. THANH TOÁN & HÓA ĐƠN
--     Chỉ phục vụ thanh toán gói đăng tin VIP cho chủ nhà.
--     Việc thanh toán tiền thuê giữa chủ nhà và người thuê
--     được thực hiện trực tiếp, không qua hệ thống.
-- ============================================================

CREATE TABLE PaymentMethods (
    method_id    INT           PRIMARY KEY IDENTITY(1,1), -- Mã phương thức thanh toán (tự tăng)
    method_name  NVARCHAR(50)  NOT NULL UNIQUE,            -- Tên phương thức: 'bank_transfer'|'momo'|'vnpay'|'zalopay'|'cash'
    logo_url     NVARCHAR(500) NULL,                       -- Đường dẫn logo của phương thức thanh toán
    is_active    BIT           DEFAULT 1                   -- Trạng thái: 1 = Đang hỗ trợ | 0 = Ngừng hỗ trợ
);

CREATE TABLE PaymentStatus (
    status_id    INT          PRIMARY KEY IDENTITY(1,1),  -- Mã trạng thái thanh toán (tự tăng)
    status_name  VARCHAR(30)  NOT NULL UNIQUE              -- Trạng thái: 'pending'|'success'|'failed'|'refunded'
);

CREATE TABLE Invoices (
    invoice_id       BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã hóa đơn (tự tăng)
    landlord_id      BIGINT        NOT NULL REFERENCES Users(user_id),          -- Chủ nhà mua gói đăng tin
    listing_id       BIGINT        NULL REFERENCES Listings(listing_id),        -- Tin đăng được áp dụng gói (NULL nếu mua trước)
    invoice_code     VARCHAR(50)   NOT NULL UNIQUE,            -- Mã số hóa đơn duy nhất
    invoice_type     VARCHAR(30)   NOT NULL DEFAULT 'post_package', -- Loại hóa đơn: 'post_package' (thanh toán gói VIP)
    total_amount     DECIMAL(15,0) NOT NULL,                   -- Tổng số tiền thanh toán gói (VNĐ)
    due_date         DATE          NOT NULL,                   -- Hạn chót thanh toán hóa đơn
    note             NVARCHAR(500) NULL,                       -- Ghi chú thêm cho hóa đơn
    status_id        INT           NOT NULL REFERENCES PaymentStatus(status_id), -- Trạng thái thanh toán hóa đơn
    created_at       DATETIME2     DEFAULT GETDATE(),          -- Thời điểm tạo hóa đơn
    updated_at       DATETIME2     DEFAULT GETDATE()           -- Thời điểm cập nhật hóa đơn gần nhất
);

CREATE INDEX IX_Invoices_Landlord ON Invoices (landlord_id); -- Index tra cứu lịch sử mua gói của chủ nhà

CREATE TABLE Payments (
    payment_id       BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã giao dịch thanh toán (tự tăng)
    invoice_id       BIGINT        NOT NULL REFERENCES Invoices(invoice_id),          -- Hóa đơn được thanh toán
    method_id        INT           NOT NULL REFERENCES PaymentMethods(method_id),     -- Phương thức thanh toán đã dùng
    status_id        INT           NOT NULL REFERENCES PaymentStatus(status_id),      -- Trạng thái giao dịch
    amount           DECIMAL(15,0) NOT NULL,                   -- Số tiền thực tế trong giao dịch (VNĐ)
    transaction_ref  VARCHAR(200)  NULL,                       -- Mã giao dịch từ cổng thanh toán (MoMo, VNPay, ZaloPay,...)
    gateway_response NVARCHAR(MAX) NULL,                       -- Toàn bộ phản hồi JSON từ cổng thanh toán (dùng để đối soát)
    paid_at          DATETIME2     NULL,                       -- Thời điểm giao dịch thanh toán thành công
    created_at       DATETIME2     DEFAULT GETDATE()           -- Thời điểm khởi tạo giao dịch
);

CREATE INDEX IX_Payments_Invoice ON Payments (invoice_id); -- Index tra cứu giao dịch theo hóa đơn



-- ============================================================
-- 12. GÓI ĐĂNG TIN (VIP / NỔI BẬT)
-- ============================================================

CREATE TABLE PostPackages (
    package_id     INT           PRIMARY KEY IDENTITY(1,1), -- Mã gói đăng tin (tự tăng)
    package_name   NVARCHAR(100) NOT NULL,                   -- Tên gói hiển thị (VD: 'Tin VIP 7 ngày')
    package_type   VARCHAR(20)   NOT NULL,                   -- Loại gói: 'free' | 'vip' | 'featured'
    duration_days  INT           NOT NULL DEFAULT 30,        -- Số ngày tin được hiển thị theo gói
    price          DECIMAL(15,0) NOT NULL DEFAULT 0,         -- Giá gói (VNĐ) - bằng 0 nếu là gói miễn phí
    priority       INT           NOT NULL DEFAULT 0,         -- Độ ưu tiên hiển thị trong danh sách (số càng cao càng lên trên)
    -- Quyền lợi phân biệt giữa các gói
    max_images     INT           NOT NULL DEFAULT 1,         -- Số ảnh tối đa được đăng kèm tin (Thường=1 | VIP=5-10 | Nổi bật=99)
    max_videos     INT           NOT NULL DEFAULT 0,         -- Số video tối đa được đăng kèm tin (Thường=0 | VIP30=1 | Nổi bật=3)
    allow_banner   BIT           NOT NULL DEFAULT 0,         -- Tin xuất hiện trên banner trang chủ: 0 = Không | 1 = Có
    badge_type     VARCHAR(20)   NULL,                       -- Loại badge hiển thị trên thẻ tin: NULL = không có | 'vip' = xanh | 'featured' = vàng
    has_analytics  BIT           NOT NULL DEFAULT 0,         -- Chủ nhà xem được thống kê lượt xem/lưu: 0 = Không | 1 = Có
    is_highlighted BIT           NOT NULL DEFAULT 0,         -- Tin được highlight nền nổi bật trong danh sách: 0 = Không | 1 = Có
    -- Thông tin chung
    description    NVARCHAR(500) NULL,                       -- Mô tả ngắn quyền lợi gói (hiển thị trên màn hình chọn gói)
    is_active      BIT           NOT NULL DEFAULT 1,         -- Trạng thái bán: 1 = Đang bán | 0 = Ngừng bán
    created_at     DATETIME2     DEFAULT GETDATE()           -- Thời điểm tạo gói
);

CREATE TABLE ListingPostPackages (
    lpp_id        BIGINT    PRIMARY KEY IDENTITY(1,1),     -- Mã bản ghi áp dụng gói (tự tăng)
    listing_id    BIGINT    NOT NULL REFERENCES Listings(listing_id) ON DELETE CASCADE, -- Tin đăng được áp dụng gói
    package_id    INT       NOT NULL REFERENCES PostPackages(package_id), -- Gói đăng tin được mua/áp dụng
    payment_id    BIGINT    NULL REFERENCES Payments(payment_id),         -- Giao dịch thanh toán gói (NULL nếu miễn phí)
    start_date    DATETIME2 NOT NULL,                       -- Thời điểm gói bắt đầu có hiệu lực
    end_date      DATETIME2 NOT NULL,                       -- Thời điểm gói hết hạn
    is_active     BIT       DEFAULT 1,                     -- Gói còn hiệu lực: 1 = Đang chạy | 0 = Đã hết hạn
    created_at    DATETIME2 DEFAULT GETDATE()               -- Thời điểm đăng ký gói
);

-- ============================================================
-- 13. BÁO CÁO VI PHẠM
-- ============================================================

CREATE TABLE Reports (
    report_id    BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã báo cáo vi phạm (tự tăng)
    reporter_id  BIGINT        NOT NULL REFERENCES Users(user_id), -- Người dùng gửi báo cáo
    listing_id   BIGINT        NULL REFERENCES Listings(listing_id), -- Tin đăng bị báo cáo (NULL nếu báo cáo người dùng)
    user_id      BIGINT        NULL REFERENCES Users(user_id),       -- Người dùng bị báo cáo (NULL nếu báo cáo tin đăng)
    reason       NVARCHAR(100) NOT NULL,                   -- Lý do báo cáo (VD: 'Tin giả', 'Lừa đảo', 'Nội dung xấu')
    description  NVARCHAR(MAX) NULL,                       -- Mô tả chi tiết hành vi vi phạm
    status       VARCHAR(20)   DEFAULT 'pending',          -- Trạng thái xử lý: 'pending'|'resolved'|'dismissed'
    resolved_by  BIGINT        NULL REFERENCES Users(user_id), -- Admin phụ trách xử lý báo cáo
    resolved_at  DATETIME2     NULL,                       -- Thời điểm báo cáo được xử lý xong
    created_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm người dùng gửi báo cáo
);

-- ============================================================
-- 14. ADMIN & THỐNG KÊ
-- ============================================================

CREATE TABLE AdminLogs (
    log_id       BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã log hành động admin (tự tăng)
    admin_id     BIGINT        NOT NULL REFERENCES Users(user_id), -- Admin thực hiện hành động
    action       NVARCHAR(100) NOT NULL,                   -- Tên hành động (VD: 'approve_listing', 'ban_user')
    target_type  VARCHAR(50)   NULL,                       -- Loại đối tượng bị tác động: 'listing' | 'user' | 'payment'
    target_id    BIGINT        NULL,                       -- ID đối tượng bị tác động
    detail       NVARCHAR(MAX) NULL,                       -- Chi tiết thay đổi, có thể lưu JSON trạng thái trước/sau
    ip_address   VARCHAR(50)   NULL,                       -- Địa chỉ IP của admin khi thực hiện hành động
    created_at   DATETIME2     DEFAULT GETDATE()           -- Thời điểm thực hiện hành động
);

CREATE TABLE DailyStats (
    stat_id          BIGINT        PRIMARY KEY IDENTITY(1,1), -- Mã bản thống kê ngày (tự tăng)
    stat_date        DATE          NOT NULL UNIQUE,            -- Ngày thống kê (mỗi ngày tạo 1 bản ghi)
    new_users        INT           DEFAULT 0,                  -- Số người dùng mới đăng ký trong ngày
    new_listings     INT           DEFAULT 0,                  -- Số tin đăng phòng mới trong ngày
    total_revenue    DECIMAL(18,0) DEFAULT 0,                  -- Tổng doanh thu bán gói VIP trong ngày (VNĐ)
    total_searches   INT           DEFAULT 0,                  -- Tổng lượt tìm kiếm trong ngày
    active_listings  INT           DEFAULT 0,                  -- Tổng số tin đang hiển thị tính đến cuối ngày
    created_at       DATETIME2     DEFAULT GETDATE()           -- Thời điểm tạo bản ghi thống kê
);

-- ============================================================
-- 15. SEED DATA - DỮ LIỆU MẶC ĐỊNH BAN ĐẦU
-- ============================================================

INSERT INTO Roles (role_name, description) VALUES
    ('tenant',   N'Người thuê phòng'),
    ('landlord', N'Chủ nhà / Người cho thuê'),
    ('admin',    N'Quản trị viên hệ thống');

INSERT INTO RoomTypes (type_name, sort_order) VALUES
    (N'Phòng trọ sinh viên',        1),
    (N'Căn hộ dịch vụ / Chung cư',  2),
    (N'Ở ghép (Roommate)',           3),
    (N'Nhà nguyên căn',              4);

INSERT INTO Amenities (name, category) VALUES
    (N'Wifi',               'basic'),
    (N'Điều hòa',           'comfort'),
    (N'Máy giặt',           'basic'),
    (N'Tủ lạnh',            'basic'),
    (N'Bếp',                'basic'),
    (N'Bãi xe',             'basic'),
    (N'Camera an ninh',     'security'),
    (N'Thang máy',          'comfort'),
    (N'Hồ bơi',             'comfort'),
    (N'Gym',                'comfort'),
    (N'Ban công',           'comfort'),
    (N'Nội thất đầy đủ',    'comfort'),
    (N'Cửa từ',             'security'),
    (N'Bảo vệ 24/7',        'security'),
    (N'Cho nuôi thú cưng',  'basic');

INSERT INTO ListingStatus (status_name) VALUES
    ('active'), ('rented'), ('hidden'), ('pending'), ('rejected');

INSERT INTO PaymentMethods (method_name) VALUES
    ('bank_transfer'), ('momo'), ('vnpay'), ('zalopay'), ('cash');

INSERT INTO PaymentStatus (status_name) VALUES
    ('pending'), ('success'), ('failed'), ('refunded');

INSERT INTO PostPackages
    (package_name, package_type, duration_days, price, priority,
     max_images, max_videos, allow_banner, badge_type, has_analytics, is_highlighted, description)
VALUES
--   Tên gói           Loại        Ngày  Giá      Ưu tiên  Ảnh  Video  Banner  Badge        Analytics  Highlight  Mô tả
(N'Tin Thường',      'free',      30,       0,   0,      1,    0,     0,     NULL,        0,         0,         N'Đăng tin miễn phí, hiển thị bình thường trong danh sách'),
(N'Tin VIP 7 ngày',  'vip',        7,   99000,   1,      5,    0,     0,     'vip',       1,         0,         N'Ưu tiên hiển thị cao hơn, badge VIP xanh, xem thống kê lượt xem'),
(N'Tin VIP 30 ngày', 'vip',       30,  299000,   1,     10,    1,     0,     'vip',       1,         0,         N'Như VIP 7 ngày nhưng dài hạn hơn, thêm hỗ trợ 1 video'),
(N'Tin Nổi Bật',     'featured',  30,  499000,   2,     99,    3,     1,     'featured',  1,         1,         N'Ưu tiên cao nhất, xuất hiện trên banner trang chủ, badge vàng nổi bật');

GO

PRINT N'✅ Database PhongTroDB v1.1 - Đã bỏ Hợp đồng, cập nhật PostPackages!';
GO