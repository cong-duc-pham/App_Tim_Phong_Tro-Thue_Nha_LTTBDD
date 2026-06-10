# SWINGS HOUSE - Ứng dụng tìm kiếm phòng trọ

Đồ án ứng dụng di động hỗ trợ tìm kiếm, đăng tin và quản lý phòng trọ. Repository gồm ứng dụng Flutter, ASP.NET Core Web API, trang quản trị và script SQL Server.

## Công nghệ sử dụng

- Flutter 3.41.6, Dart 3.11.4
- ASP.NET Core 8 Web API, Entity Framework Core 8, SignalR
- SQL Server
- Firebase Authentication, Firebase Cloud Messaging và Firebase Storage
- Cloudinary để lưu ảnh
- BLoC, Dio, GoRouter, Shared Preferences và SQLite
- Gemini API cho dịch thuật và trợ lý AI (tùy chọn)

Danh sách package Flutter đầy đủ nằm trong `pubspec.yaml`. Package .NET nằm trong `backend/Backend_API/Backend_API/Backend_API.csproj`.

## Cấu trúc repository

```text
lib/                                      Mã nguồn Flutter
android/                                  Cấu hình Android và Firebase Android
ios/                                      Cấu hình iOS
backend/Backend_API/                      ASP.NET Core API và trang quản trị
backend/Backend_API/Services/Data/
  phongtro_database1.sql                  Script tạo database và dữ liệu nền
  sample_data.sql                         Tài khoản và tin đăng kiểm thử
backend/firebase-rules/                   Firebase rules
docs/                                     Báo cáo và tài liệu nộp bài
```

## Yêu cầu môi trường

- Flutter `3.41.6` stable và Dart `3.11.4` (hoặc Flutter tương thích Dart `>=3.0.0 <4.0.0`)
- Android Studio, Android SDK và một Android Emulator
- .NET SDK 8
- SQL Server 2019 trở lên và SQL Server Management Studio
- Tài khoản Firebase, Cloudinary; Gemini/PayOS/SMS chỉ cần khi kiểm thử các chức năng tương ứng

Kiểm tra môi trường:

```powershell
flutter doctor
flutter --version
dotnet --version
```

## 1. Clone và cài dependency

```powershell
git clone git@github.com:cong-duc-pham/App_Tim_Phong_Tro-Thue_Nha_LTTBDD.git
cd App_Tim_Phong_Tro-Thue_Nha_LTTBDD
flutter pub get
dotnet restore .\backend\Backend_API\Backend_API\Backend_API.csproj
```

## 2. Khởi tạo SQL Server

1. Mở SQL Server Management Studio và kết nối SQL Server.
2. Mở file `backend/Backend_API/Services/Data/phongtro_database1.sql`.
3. Chạy toàn bộ `phongtro_database1.sql`. Script sẽ tạo lại database `PhongTroDB`, các bảng, procedure và dữ liệu nền.
4. Chạy tiếp `backend/Backend_API/Services/Data/sample_data.sql` để thêm địa điểm, tài khoản và tin đăng kiểm thử.
5. Sao chép `backend/Backend_API/Backend_API/appsettings.Local.example.json` thành `appsettings.Local.json`.
6. Sửa `ConnectionStrings.DefaultConnection` theo SQL Server trên máy.

Cấu hình mặc định dùng SQL Server tại `localhost,1434`, tài khoản `sa`. Không commit file `appsettings.Local.json`.

## 3. Cấu hình Firebase

### Android

File `android/app/google-services.json` đã được cung cấp trong repository. Khi dùng Firebase project khác:

1. Tạo project trên Firebase Console.
2. Thêm Android app có package name `com.example.ung_dung_tim_kiem_tro`.
3. Tải `google-services.json` và đặt tại `android/app/google-services.json`.
4. Bật Authentication providers cần dùng: Email/Password, Google và Facebook.
5. Bật Cloud Messaging và Storage.
6. Deploy rules trong `backend/firebase-rules/storage.rules`.

### Backend Firebase Admin

1. Firebase Console > Project settings > Service accounts.
2. Tạo private key và lưu ngoài Git với tên `firebase-adminsdk.json`.
3. Đặt đường dẫn file trong `Firebase.CredentialPath` của `appsettings.Local.json`.

Không commit Firebase Admin private key. Backend vẫn chạy được nếu chưa cấu hình Admin SDK, nhưng FCM và các chức năng xác thực Firebase phía server sẽ không hoạt động.

### iOS

Project chưa cung cấp `GoogleService-Info.plist`. Muốn chạy iOS, đăng ký iOS app trong Firebase, tải file và đặt tại `ios/Runner/GoogleService-Info.plist`, sau đó thêm file vào target Runner trong Xcode.

### Firestore

Dữ liệu nghiệp vụ của hệ thống nằm trong SQL Server, không yêu cầu collection/document Firestore mẫu. Package Firestore chỉ là dependency phía client. Rules deny-by-default nằm tại `backend/firebase-rules/firestore.rules`.

## 4. Cấu hình dịch vụ backend

Điền các giá trị cần thiết trong `appsettings.Local.json` hoặc dùng biến môi trường .NET:

```powershell
$env:ConnectionStrings__DefaultConnection="Server=localhost,1434;Initial Catalog=PhongTroDB;User ID=sa;Password=<password>;Encrypt=True;TrustServerCertificate=True"
$env:JwtSettings__SecretKey="<chuoi-bi-mat-toi-thieu-32-ky-tu>"
$env:GEMINI_API_KEY="<gemini-api-key>"
```

Cloudinary, Email, PayOS và SMS là các tích hợp tùy chọn. Thiếu cấu hình tương ứng thì chức năng upload ảnh, gửi email, thanh toán hoặc SMS thật sẽ không hoạt động.

## 5. Chạy backend

```powershell
dotnet run --project .\backend\Backend_API\Backend_API\Backend_API.csproj
```

- HTTP API: `http://localhost:61795`
- HTTPS API: `https://localhost:61794`
- Swagger: `http://localhost:61795/swagger`
- Trang quản trị: `http://localhost:61795`

## 6. Chạy Flutter

Android Emulator dùng địa chỉ mặc định `10.0.2.2` để gọi máy host:

```powershell
flutter run
```

Thiết bị Android thật phải cùng mạng với máy chạy backend. Thay `<IP-MAY-TINH>` bằng IPv4 LAN:

```powershell
flutter run --dart-define=API_BASE_URL=http://<IP-MAY-TINH>:61795/api
```

Nếu Windows Firewall chặn kết nối, cho phép inbound TCP cổng `61795`. Backend đã lắng nghe trên `0.0.0.0`.

## Tài khoản kiểm thử

```text
Người thuê: tenant@swingshouse.test   / Test@123
Chủ trọ:    landlord@swingshouse.test / Test@123
Quản trị:   admin@swingshouse.test    / Admin@123
```

Các tài khoản này chỉ dùng cho môi trường chấm bài, được tạo bởi `sample_data.sql`.

## Kiểm tra trước khi nộp

```powershell
flutter pub get
flutter analyze
flutter test
dotnet build .\backend\Backend_API\Backend_API\Backend_API.csproj
```

- Báo cáo PDF: `docs/LTTBDD_BTL.pdf`.
- Xác nhận clone repository trên máy/thư mục sạch và chạy lại được.
- Đổi hoặc thu hồi mọi API key đã từng commit.
- Commit và push toàn bộ source, script database, rules và tài liệu.
- Tạo một file `.txt` duy nhất chứa URL repository để upload lên hệ thống.
- File link nộp bài của nhóm: `6451071021_6451071016_6451071081_DALTMB.txt`.

## Lưu ý bảo mật

Không commit `firebase-adminsdk.json`, `appsettings.Local.json`, `.env`, private key, mật khẩu email, JWT secret hoặc API secret. `google-services.json` là cấu hình nhận diện ứng dụng Android, không phải Firebase Admin private key; vẫn nên giới hạn API key theo package name và SHA certificate trong Google Cloud Console.
