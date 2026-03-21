// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // ─── Border radius ───────────────────────────────────────────────────────
  static const double radiusSm   = 8.0;
  static const double radiusMd   = 12.0;
  static const double radiusLg   = 16.0;
  static const double radiusXl   = 20.0;
  static const double radiusXxl  = 28.0;
  static const double radiusFull = 999.0; // Pill / circle

  // ─── Spacing ─────────────────────────────────────────────────────────────
  static const double spacingXs  = 4.0;
  static const double spacingSm  = 8.0;
  static const double spacingMd  = 12.0;
  static const double spacingLg  = 16.0;
  static const double spacingXl  = 20.0;
  static const double spacingXxl = 24.0;

  // ─── Padding page ────────────────────────────────────────────────────────
  static const double paddingH   = 20.0; // Padding ngang toàn trang
  static const double paddingV   = 16.0; // Padding dọc section

  // ─── Card ────────────────────────────────────────────────────────────────
  static const double cardWidth       = 200.0; // Card ngang cuộn
  static const double cardImgHeight   = 110.0; // Chiều cao ảnh card
  static const double cardFullImgW    = 90.0;  // Chiều rộng ảnh card full
  static const double borderWidth     = 1.0;

  // ─── Bottom nav ──────────────────────────────────────────────────────────
  static const double navHeight       = 60.0;
  static const double navAddBtnSize   = 48.0;

  // ─── Icon sizes ──────────────────────────────────────────────────────────
  static const double iconXs   = 13.0;
  static const double iconSm   = 16.0;
  static const double iconMd   = 20.0;
  static const double iconLg   = 24.0;
  static const double iconXl   = 32.0;

  // ─── Animation durations ─────────────────────────────────────────────────
  static const Duration splashDuration      = Duration(milliseconds: 2500);
  static const Duration animFast            = Duration(milliseconds: 200);
  static const Duration animNormal          = Duration(milliseconds: 300);
  static const Duration animSlow            = Duration(milliseconds: 400);
  static const Duration animPageTransition  = Duration(milliseconds: 500);

  // ─── SharedPreferences keys ──────────────────────────────────────────────
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyUserToken      = 'user_token';
  static const String keyUserId         = 'user_id';
  static const String keyUserRole       = 'user_role';

  // ─── Routes ──────────────────────────────────────────────────────────────
  static const String routeSplash      = '/';
  static const String routeOnboarding  = '/onboarding';
  static const String routeHome        = '/home';
  static const String routeLogin       = '/login';
  static const String routeRegister    = '/register';
  static const String routeProfile     = '/profile';
  static const String routeListingDetail = '/listing/:id';
  static const String routePostListing = '/post-listing';
  static const String routeChat        = '/chat';
  static const String routeFavorites   = '/favorites';

  // ─── Pagination ──────────────────────────────────────────────────────────
  static const int pageSize = 10; // Số item mỗi trang

  // ─── Map / Location ──────────────────────────────────────────────────────
  static const int defaultSearchRadiusKm = 5;
  static const double defaultLat = 10.7769; // Mặc định: TP.HCM
  static const double defaultLng = 106.7009;

  // ─── Image limits ────────────────────────────────────────────────────────
  static const int maxImgFree      = 1;
  static const int maxImgVip       = 10;
  static const int maxImgFeatured  = 99;
  static const int maxVideoVip30   = 1;
  static const int maxVideoFeatured = 3;
}