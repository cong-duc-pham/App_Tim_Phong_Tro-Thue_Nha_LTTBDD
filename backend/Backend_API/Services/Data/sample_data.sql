USE PhongTroDB;
GO

SET NOCOUNT ON;

DECLARE @AdminRoleId INT = (SELECT role_id FROM Roles WHERE role_name = 'admin');
DECLARE @TenantRoleId INT = (SELECT role_id FROM Roles WHERE role_name = 'tenant');
DECLARE @LandlordRoleId INT = (SELECT role_id FROM Roles WHERE role_name = 'landlord');

IF NOT EXISTS (SELECT 1 FROM Provinces WHERE province_code = 'HCM')
    INSERT INTO Provinces (province_name, province_code)
    VALUES (N'Thành phố Hồ Chí Minh', 'HCM');

DECLARE @ProvinceId INT =
    (SELECT province_id FROM Provinces WHERE province_code = 'HCM');

IF NOT EXISTS (
    SELECT 1 FROM Districts
    WHERE province_id = @ProvinceId AND district_code = 'Q10'
)
    INSERT INTO Districts (province_id, district_name, district_code)
    VALUES (@ProvinceId, N'Quận 10', 'Q10');

DECLARE @DistrictId INT =
    (SELECT district_id FROM Districts
     WHERE province_id = @ProvinceId AND district_code = 'Q10');

IF NOT EXISTS (
    SELECT 1 FROM Wards
    WHERE district_id = @DistrictId AND ward_code = 'P12'
)
    INSERT INTO Wards (district_id, ward_name, ward_code)
    VALUES (@DistrictId, N'Phường 12', 'P12');

DECLARE @WardId INT =
    (SELECT ward_id FROM Wards
     WHERE district_id = @DistrictId AND ward_code = 'P12');

-- Passwords:
-- admin@swingshouse.test    / Admin@123
-- landlord@swingshouse.test / Test@123
-- tenant@swingshouse.test   / Test@123
IF NOT EXISTS (SELECT 1 FROM Users WHERE email = 'admin@swingshouse.test')
    INSERT INTO Users (
        full_name, email, phone, password_hash, role_id,
        is_verified, is_email_verified, is_active
    )
    VALUES (
        N'Quản trị viên Demo', 'admin@swingshouse.test', '0900000001',
        '$2a$11$uUwfLaVetR9.sZDixhZN4eyLH4DSF4jb61.rhVHyKY8j6/wKHzmb2',
        @AdminRoleId, 1, 1, 1
    );

IF NOT EXISTS (SELECT 1 FROM Users WHERE email = 'landlord@swingshouse.test')
    INSERT INTO Users (
        full_name, email, phone, password_hash, role_id,
        is_verified, is_email_verified, is_active
    )
    VALUES (
        N'Chủ trọ Demo', 'landlord@swingshouse.test', '0900000002',
        '$2a$11$ZYlONTDLqUF.vSptyFssr.NPETveYOkiMW0vQX43t2.TdRggzvL92',
        @LandlordRoleId, 1, 1, 1
    );

IF NOT EXISTS (SELECT 1 FROM Users WHERE email = 'tenant@swingshouse.test')
    INSERT INTO Users (
        full_name, email, phone, password_hash, role_id,
        is_verified, is_email_verified, is_active
    )
    VALUES (
        N'Người thuê Demo', 'tenant@swingshouse.test', '0900000003',
        '$2a$11$ZYlONTDLqUF.vSptyFssr.NPETveYOkiMW0vQX43t2.TdRggzvL92',
        @TenantRoleId, 1, 1, 1
    );

DECLARE @TenantId BIGINT =
    (SELECT user_id FROM Users WHERE email = 'tenant@swingshouse.test');
DECLARE @LandlordId BIGINT =
    (SELECT user_id FROM Users WHERE email = 'landlord@swingshouse.test');
DECLARE @RoomTypeId INT =
    (SELECT TOP 1 type_id FROM RoomTypes ORDER BY sort_order, type_id);
DECLARE @ActiveStatusId INT =
    (SELECT status_id FROM ListingStatus WHERE status_name = 'active');

IF NOT EXISTS (SELECT 1 FROM UserPreferences WHERE user_id = @TenantId)
    INSERT INTO UserPreferences (
        user_id, preferred_area, min_price, max_price,
        search_radius_km, onboarding_done
    )
    VALUES (
        @TenantId, N'Quận 10', 2000000, 5000000, 10, 1
    );

IF NOT EXISTS (
    SELECT 1 FROM Listings
    WHERE landlord_id = @LandlordId AND title = N'Phòng trọ sinh viên gần Đại học Bách Khoa'
)
    INSERT INTO Listings (
        landlord_id, type_id, status_id, title, description,
        price, area, floor, total_floors, max_occupants,
        province_id, district_id, ward_id, street_address,
        latitude, longitude, is_verified, is_featured, is_new,
        allow_pet, image_0, electric_price, water_price,
        internet_price, parking_price, available_from, expired_at
    )
    VALUES (
        @LandlordId, @RoomTypeId, @ActiveStatusId,
        N'Phòng trọ sinh viên gần Đại học Bách Khoa',
        N'Phòng sạch sẽ, có cửa sổ, khu vực an ninh và thuận tiện đi học.',
        3200000, 22, 2, 4, 2,
        @ProvinceId, @DistrictId, @WardId, N'268 Tô Hiến Thành',
        10.7722, 106.6605, 1, 1, 1,
        0, 'http://10.0.2.2:61795/uploads/listings/70005/cover.jpg',
        3500, 15000, 100000, 100000, CAST(GETDATE() AS DATE),
        DATEADD(DAY, 90, GETDATE())
    );

IF NOT EXISTS (
    SELECT 1 FROM Listings
    WHERE landlord_id = @LandlordId AND title = N'Phòng đầy đủ nội thất tại Quận 10'
)
    INSERT INTO Listings (
        landlord_id, type_id, status_id, title, description,
        price, area, floor, total_floors, max_occupants,
        province_id, district_id, ward_id, street_address,
        latitude, longitude, is_verified, is_featured, is_new,
        allow_pet, image_0, electric_price, water_price,
        internet_price, parking_price, available_from, expired_at
    )
    VALUES (
        @LandlordId, @RoomTypeId, @ActiveStatusId,
        N'Phòng đầy đủ nội thất tại Quận 10',
        N'Có máy lạnh, tủ lạnh, máy giặt chung và giờ giấc tự do.',
        4500000, 28, 3, 5, 2,
        @ProvinceId, @DistrictId, @WardId, N'450 Thành Thái',
        10.7688, 106.6642, 1, 0, 1,
        1, 'http://10.0.2.2:61795/uploads/listings/60006/cover.jpg',
        3800, 18000, 0, 120000, CAST(GETDATE() AS DATE),
        DATEADD(DAY, 90, GETDATE())
    );

INSERT INTO ListingAmenities (listing_id, amenity_id)
SELECT l.listing_id, a.amenity_id
FROM Listings l
CROSS JOIN Amenities a
WHERE l.landlord_id = @LandlordId
  AND l.title IN (
      N'Phòng trọ sinh viên gần Đại học Bách Khoa',
      N'Phòng đầy đủ nội thất tại Quận 10'
  )
  AND a.name IN (N'Wifi', N'Bai xe', N'Camera an ninh')
  AND NOT EXISTS (
      SELECT 1 FROM ListingAmenities la
      WHERE la.listing_id = l.listing_id
        AND la.amenity_id = a.amenity_id
  );

PRINT N'Đã tạo dữ liệu mẫu và tài khoản kiểm thử.';
GO
