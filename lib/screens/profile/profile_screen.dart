// lib/screens/profile/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/logout_helper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/listing_repository.dart';

// ─── Model tạm (thay bằng Bloc/Repository sau) ────────────────────────────────
class _UserInfo {
  final String fullName;
  final String email;
  final String phone;
  final String role; // tenant | landlord
  final bool isVerified;
  final String? avatarUrl;
  final DateTime createdAt;
  final int favoritesCount;
  final int listingsCount;
  final int reviewsCount;
  final bool isPhoneVerified;

  const _UserInfo({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isVerified,
    this.avatarUrl,
    required this.createdAt,
    this.favoritesCount = 0,
    this.listingsCount = 0,
    this.reviewsCount = 0,
    this.isPhoneVerified = false,
  });
}

// Dữ liệu mẫu — thay bằng API call thật
// ignore: unused_element
final _mockUser = _UserInfo(
  fullName: 'Phạm Công Đức',
  email: 'duc.pham@example.com',
  phone: '0901 234 567',
  role: 'tenant',
  isVerified: true,
  createdAt: DateTime(2024, 9, 1),
  favoritesCount: 12,
  listingsCount: 0,
  reviewsCount: 3,
);

// ─── ProfileScreen ─────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late _UserInfo _user;
  bool _isLoggedIn = false;
  bool _isLoading = true;
  double? _appRating;
  String _appRatingComment = '';
  DateTime? _appRatingSubmittedAt;
  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final verifyPhoneStatus = prefs.getBool('verify_phone_status') ?? false;
    final verifyPhoneNumber = prefs.getString('verify_phone_number') ?? '';
    _loadAppRatingFromPrefs(prefs);
    final savedToken = prefs.getString(AppConstants.keyUserToken);
    final savedUserId = prefs.getString(AppConstants.keyUserId);
    if (savedToken != null &&
        savedToken.isNotEmpty &&
        savedUserId != null &&
        savedUserId.isNotEmpty) {
      final savedEmail = prefs.getString('user_email') ?? '';
      final savedFullName = prefs.getString('user_full_name');
      final savedPhone = prefs.getString('user_phone') ?? '';
      final savedRole = prefs.getString(AppConstants.keyUserRole);
      final isVerifyMain = prefs.getBool('verify_account_main_status') ?? false;
      var effectiveRole = _normalizeRole(savedRole);
      var listingsCount = 0;
      try {
        final listings = await ListingRepository().getMyListings();
        listingsCount = listings.length;
        if (listings.isNotEmpty && effectiveRole != 'admin') {
          effectiveRole = 'landlord';
          await prefs.setString(AppConstants.keyUserRole, 'landlord');
        }
      } catch (_) {
        // Giữ role đã lưu nếu backend chưa sẵn sàng.
      }
      if (!mounted) return;
      setState(() {
        _user = _UserInfo(
          fullName: savedFullName?.trim().isNotEmpty == true
              ? savedFullName!.trim()
              : (savedEmail.isNotEmpty
                  ? savedEmail.split('@').first
                  : 'Người dùng'),
          email: savedEmail,
          phone: verifyPhoneStatus ? verifyPhoneNumber : savedPhone,
          role: effectiveRole,
          isVerified: isVerifyMain,
          createdAt: DateTime.now(),
          listingsCount: listingsCount,
          isPhoneVerified: verifyPhoneStatus,
        );
        _isLoggedIn = true;
        _isLoading = false;
      });
      return;
    }
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
      return;
    }
    final fallbackName = firebaseUser.displayName?.trim().isNotEmpty == true
        ? firebaseUser.displayName!.trim()
        : (firebaseUser.email?.split('@').first ?? 'Người dùng');
    var userInfo = _UserInfo(
      fullName: fallbackName,
      email: firebaseUser.email ?? '',
      phone: verifyPhoneStatus
          ? verifyPhoneNumber
          : (firebaseUser.phoneNumber ?? ''),
      role: 'tenant',
      isVerified: firebaseUser.emailVerified,
      avatarUrl: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
      isPhoneVerified: verifyPhoneStatus,
    );
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        final createdAt = data['createdAt'];
        userInfo = _UserInfo(
          fullName: (data['fullName'] as String?)?.trim().isNotEmpty == true
              ? (data['fullName'] as String).trim()
              : fallbackName,
          email: (data['email'] as String?) ?? firebaseUser.email ?? '',
          phone: verifyPhoneStatus
              ? verifyPhoneNumber
              : ((data['phone'] as String?) ?? firebaseUser.phoneNumber ?? ''),
          role: (data['role'] as String?) ?? 'tenant',
          isVerified:
              (data['isVerified'] as bool?) ?? firebaseUser.emailVerified,
          avatarUrl: (data['avatar'] as String?) ?? firebaseUser.photoURL,
          createdAt: createdAt is Timestamp
              ? createdAt.toDate()
              : firebaseUser.metadata.creationTime ?? DateTime.now(),
          favoritesCount: (data['favoritesCount'] as num?)?.toInt() ?? 0,
          listingsCount: (data['listingsCount'] as num?)?.toInt() ?? 0,
          reviewsCount: (data['reviewsCount'] as num?)?.toInt() ?? 0,
          isPhoneVerified: verifyPhoneStatus,
        );
      }
    } catch (_) {
      // Giữ dữ liệu từ Firebase Auth nếu Firestore chưa sẵn sàng.
    }
    final isVerifyMain = prefs.getBool('verify_account_main_status') ?? false;
    if (isVerifyMain) {
      userInfo = _UserInfo(
        fullName: userInfo.fullName,
        email: userInfo.email,
        phone: userInfo.phone,
        role: userInfo.role,
        isVerified: true,
        avatarUrl: userInfo.avatarUrl,
        createdAt: userInfo.createdAt,
        favoritesCount: userInfo.favoritesCount,
        listingsCount: userInfo.listingsCount,
        reviewsCount: userInfo.reviewsCount,
        isPhoneVerified: userInfo.isPhoneVerified,
      );
    } else {
      // Nếu chưa kích hoạt mức độ tin cậy tuyệt đối, vẫn có thể fallback về trạng thái emailVerified thực tế
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && firebaseUser.emailVerified) {
        userInfo = _UserInfo(
          fullName: userInfo.fullName,
          email: userInfo.email,
          phone: userInfo.phone,
          role: userInfo.role,
          isVerified: true,
          avatarUrl: userInfo.avatarUrl,
          createdAt: userInfo.createdAt,
          favoritesCount: userInfo.favoritesCount,
          listingsCount: userInfo.listingsCount,
          reviewsCount: userInfo.reviewsCount,
          isPhoneVerified: userInfo.isPhoneVerified,
        );
      }
    }
    try {
      final listings = await ListingRepository().getMyListings();
      if (listings.isNotEmpty && _normalizeRole(userInfo.role) != 'admin') {
        userInfo = _UserInfo(
          fullName: userInfo.fullName,
          email: userInfo.email,
          phone: userInfo.phone,
          role: 'landlord',
          isVerified: userInfo.isVerified,
          avatarUrl: userInfo.avatarUrl,
          createdAt: userInfo.createdAt,
          favoritesCount: userInfo.favoritesCount,
          listingsCount: listings.length,
          reviewsCount: userInfo.reviewsCount,
          isPhoneVerified: userInfo.isPhoneVerified,
        );
        await prefs.setString(AppConstants.keyUserRole, 'landlord');
      }
    } catch (_) {
      // Không chặn profile nếu không tải được danh sách tin.
    }
    if (!mounted) return;
    setState(() {
      _user = userInfo;
      _isLoggedIn = true;
      _isLoading = false;
    });
  }

  void _loadAppRatingFromPrefs(SharedPreferences prefs) {
    _appRating = prefs.getDouble('app_rating_score');
    _appRatingComment = prefs.getString('app_rating_comment') ?? '';
    final submittedRaw = prefs.getString('app_rating_submitted_at');
    _appRatingSubmittedAt =
        submittedRaw == null ? null : DateTime.tryParse(submittedRaw);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (!_isLoggedIn) return _buildNotLoggedIn();
    return Scaffold(
      backgroundColor: context.profileBg,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildStats()),
          SliverToBoxAdapter(
              child: _buildMenuSection(
            title: 'profile_account'.tr,
            items: [
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'profile_personal_info'.tr,
                onTap: () => _showEditProfile(),
              ),
              _MenuItem(
                icon: Icons.lock_outline_rounded,
                label: 'profile_change_password'.tr,
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppConstants.routeChangePassword);
                },
              ),
              _MenuItem(
                icon: Icons.verified_user_outlined,
                label: 'profile_verify_account'.tr,
                trailing:
                    _user.isVerified ? _VerifiedBadge() : _UnverifiedBadge(),
                onTap: () async {
                  await context.push(AppConstants.routeVerifyAccount);
                  _loadCurrentUser();
                },
              ),
              _MenuItem(
                icon: Icons.tune_rounded,
                label: 'profile_preferences'.tr,
                onTap: () {
                  context.push('${AppConstants.routePreference}?from=profile');
                },
              ),
            ],
          )),
          SliverToBoxAdapter(
              child: _buildMenuSection(
            title: 'profile_activity'.tr,
            items: [
              _MenuItem(
                icon: Icons.favorite_border_rounded,
                label: 'profile_saved_rooms'.tr,
                badge:
                    _user.favoritesCount > 0 ? '${_user.favoritesCount}' : null,
                onTap: () => context.push(AppConstants.routeFavorites),
              ),
              _MenuItem(
                icon: Icons.rate_review_outlined,
                label: 'profile_my_reviews'.tr,
                badge: _user.reviewsCount > 0 ? '${_user.reviewsCount}' : null,
                onTap: () => context.push(AppConstants.routeMyReviews),
              ),
              _MenuItem(
                icon: Icons.history_rounded,
                label: 'profile_search_history'.tr,
                onTap: () => context.push(AppConstants.routeSearchHistory),
              ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: 'settings_title'.tr,
                onTap: () => context.push(AppConstants.routeSettings),
              ),
              if (_user.role == 'landlord') ...[
                _MenuItem(
                  icon: Icons.home_work_outlined,
                  label: 'profile_my_listings'.tr,
                  badge:
                      _user.listingsCount > 0 ? '${_user.listingsCount}' : null,
                  onTap: () => context.push(AppConstants.routeMyListings),
                ),
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'profile_invoices'.tr,
                  onTap: () => context.push(AppConstants.routeInvoices),
                ),
              ],
            ],
          )),
          SliverToBoxAdapter(
              child: _buildMenuSection(
            title: 'profile_support'.tr,
            items: [
              _MenuItem(
                icon: Icons.help_outline_rounded,
                label: 'profile_support_center'.tr,
                onTap: () => context.push(AppConstants.routeSupportCenter),
              ),
              _MenuItem(
                icon: Icons.bug_report_outlined,
                label: 'profile_report_issue'.tr,
                onTap: () => context.push(AppConstants.routeReportIssue),
              ),
              _MenuItem(
                icon: Icons.star_border_rounded,
                label: 'profile_rate_app'.tr,
                trailing: _appRating == null
                    ? null
                    : Text(
                        '${_appRating!.toStringAsFixed(0)}/5',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningText,
                        ),
                      ),
                onTap: () => _showAppRatingSheet(),
              ),
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'profile_about_app'.tr,
                trailing: const Text(
                  'v1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                onTap: () => context.push(AppConstants.routeAbout),
              ),
            ],
          )),
          SliverToBoxAdapter(child: _buildLogoutBtn()),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Header (avatar + tên + vai trò) ─────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'nav_profile'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.go(AppConstants.routeNotifications),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Avatar
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  alignment: Alignment.center,
                  child: _user.avatarUrl != null
                      ? ClipOval(
                          child: Image.network(
                            _user.avatarUrl!,
                            width: 84,
                            height: 84,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Text(
                          _user.fullName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Tên
            Text(
              _user.fullName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            // Email
            Text(
              _user.email,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 5),
            // Phone Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _user.isPhoneVerified
                        ? Icons.phone_iphone_rounded
                        : Icons.warning_amber_rounded,
                    size: 13,
                    color: _user.isPhoneVerified
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.orangeAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _user.isPhoneVerified
                        ? _user.phone
                        : 'verify_phone_unverified'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: _user.isPhoneVerified
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: _user.isPhoneVerified
                          ? Colors.white.withValues(alpha: 0.9)
                          : Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Role badge + Verified
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _user.role == 'landlord'
                            ? Icons.home_work_rounded
                            : Icons.person_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _user.role == 'landlord'
                            ? 'profile_landlord'.tr
                            : 'profile_tenant'.tr,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_user.isVerified) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull),
                      border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          'profile_verified'.tr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            // Curved bottom
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: context.profileBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats (3 số liệu) ────────────────────────────────────────────────────
  Widget _buildStats() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: Row(
        children: [
          _StatItem(
            value: '${_user.favoritesCount}',
            label: 'profile_favorites_count'.tr,
            icon: Icons.favorite_rounded,
            color: AppColors.error,
          ),
          _Divider(),
          _StatItem(
            value: _formatJoinDate(_user.createdAt),
            label: 'profile_joined_date'.tr,
            icon: Icons.calendar_today_rounded,
            color: AppColors.primary,
          ),
          _Divider(),
          _StatItem(
            value: '${_user.reviewsCount}',
            label: 'profile_reviews_count'.tr,
            icon: Icons.star_rounded,
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }

  // ── Menu Section ─────────────────────────────────────────────────────────
  Widget _buildMenuSection({
    required String title,
    required List<_MenuItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 2),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ).copyWith(color: context.profileTextMuted),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: context.profileCard,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: context.profileBorder),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    _MenuTile(item: item),
                    if (i < items.length - 1)
                      Divider(
                        height: 1,
                        color: context.profileBorder,
                        indent: 52,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Logout Button ────────────────────────────────────────────────────────
  Widget _buildLogoutBtn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: GestureDetector(
        onTap: _confirmLogout,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.errorBg,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                'profile_logout'.tr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Not logged in state ───────────────────────────────────────────────────
  Widget _buildLoading() {
    return Scaffold(
      backgroundColor: context.profileBg,
      body: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Scaffold(
      backgroundColor: context.profileBg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Row(
                children: [
                  Text(
                    'nav_profile'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingH),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusXl),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 36,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'profile_not_logged_title'.tr,
                        style: AppTextStyles.h2.copyWith(
                          color: context.profileText,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'profile_not_logged_desc'.tr,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: context.profileTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go(AppConstants.routeLogin),
                          child: Text('profile_login_now'.tr),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              context.go(AppConstants.routeRegister),
                          child: Text('profile_register_now'.tr),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        title: Text('profile_logout_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('profile_logout_desc'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              final router = GoRouter.of(context);
              Navigator.pop(dialogContext);
              if (!mounted) return;
              await LogoutHelper.signOutAndGoToLogin(router);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('profile_logout'.tr),
          ),
        ],
      ),
    );
  }

  void _showEditProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: _user,
        onSaved: _loadCurrentUser,
      ),
    );
  }

  void _showAppRatingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppRatingSheet(
        initialRating: _appRating ?? 5,
        initialComment: _appRatingComment,
        submittedAt: _appRatingSubmittedAt,
        onSubmit: (rating, comment) async {
          final prefs = await SharedPreferences.getInstance();
          final submittedAt = DateTime.now();
          await prefs.setDouble('app_rating_score', rating);
          await prefs.setString('app_rating_comment', comment);
          await prefs.setString(
            'app_rating_submitted_at',
            submittedAt.toIso8601String(),
          );
          if (!mounted) return;
          setState(() {
            _appRating = rating;
            _appRatingComment = comment;
            _appRatingSubmittedAt = submittedAt;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('profile_app_rating_thanks'.tr),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _formatJoinDate(DateTime date) {
    return '${date.month}/${date.year}';
  }

  String _normalizeRole(String? role) {
    final value = role?.trim().toLowerCase() ?? '';
    if (value.contains('landlord') || value.contains('owner')) {
      return 'landlord';
    }
    return 'tenant';
  }
}

// ─── Edit Profile Bottom Sheet ───────────────────────────────────────────────
class _AppRatingSheet extends StatefulWidget {
  final double initialRating;
  final String initialComment;
  final DateTime? submittedAt;
  final Future<void> Function(double rating, String comment) onSubmit;
  const _AppRatingSheet({
    required this.initialRating,
    required this.initialComment,
    required this.submittedAt,
    required this.onSubmit,
  });
  @override
  State<_AppRatingSheet> createState() => _AppRatingSheetState();
}

class _AppRatingSheetState extends State<_AppRatingSheet> {
  late double _rating;
  late final TextEditingController _commentCtrl;
  bool _isSubmitting = false;
  @override
  void initState() {
    super.initState();
    _rating = widget.initialRating;
    _commentCtrl = TextEditingController(text: widget.initialComment);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    HapticFeedback.lightImpact();
    setState(() => _isSubmitting = true);
    await widget.onSubmit(_rating, _commentCtrl.text.trim());
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
  }

  String _formatSubmittedAt(DateTime time) {
    final local = time.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.profileBorder,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'profile_rate_app'.tr,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.profileText,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: context.profileTextMuted),
                  ),
                ],
              ),
            ),
            Divider(height: 20, color: context.profileBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        RatingBar.builder(
                          initialRating: _rating,
                          minRating: 1,
                          maxRating: 5,
                          allowHalfRating: false,
                          itemCount: 5,
                          itemSize: 36,
                          unratedColor: AppColors.border,
                          itemBuilder: (context, index) => const Icon(
                            Icons.star_rounded,
                            color: AppColors.warning,
                          ),
                          onRatingUpdate: (rating) {
                            setState(() => _rating = rating);
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_rating.toStringAsFixed(0)}/5',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.profileText,
                          ),
                        ),
                        if (widget.submittedAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${'profile_update_rating'.tr}: ${_formatSubmittedAt(widget.submittedAt!)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: context.profileTextMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'profile_feedback'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.profileTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _commentCtrl,
                    minLines: 4,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'profile_rating_hint'.tr,
                      hintStyle: AppTextStyles.inputHint.copyWith(
                        color: context.profileTextMuted,
                      ),
                      filled: true,
                      fillColor: context.profileInputFill,
                      counterStyle: TextStyle(
                        fontSize: 10,
                        color: context.profileTextMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: BorderSide(color: context.profileBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: BorderSide(color: context.profileBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.star_rounded, size: 18),
                      label: Text(
                        widget.submittedAt == null
                            ? 'profile_send_rating'.tr
                            : 'profile_update_rating'.tr,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  final _UserInfo user;
  final VoidCallback onSaved;
  const _EditProfileSheet({
    required this.user,
    required this.onSaved,
  });
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.fullName);
    _phoneCtrl = TextEditingController(text: widget.user.phone);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXxl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.profileBorder,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Text(
                    'profile_edit_info'.tr,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: context.profileText,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: context.profileTextMuted),
                  ),
                ],
              ),
            ),
            Divider(height: 20, color: context.profileBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _FormField(
                    ctrl: _nameCtrl,
                    label: 'profile_full_name'.tr,
                    hint: 'profile_full_name'.tr,
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    ctrl: _phoneCtrl,
                    label: 'profile_phone'.tr,
                    hint: '0901 234 567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    readOnly: true,
                    suffixIcon: Icon(
                      widget.user.isPhoneVerified
                          ? Icons.verified_user_rounded
                          : Icons.warning_amber_rounded,
                      color: widget.user.isPhoneVerified
                          ? AppColors.success
                          : AppColors.warning,
                      size: 18,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.push(AppConstants.routeVerifyAccount).then((_) {
                        widget.onSaved();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              final name = _nameCtrl.text.trim();
                              final phone = _phoneCtrl.text.trim();
                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('profile_name_required'.tr),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }
                              setState(() => _isSaving = true);
                              final messenger = ScaffoldMessenger.of(context);
                              final navigator = Navigator.of(context);
                              try {
                                await AuthRepository().updateProfile(
                                  fullName: name,
                                  phone: phone,
                                );
                                if (!mounted) return;
                                widget.onSaved();
                                navigator.pop();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('profile_update_success'.tr),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(e
                                        .toString()
                                        .replaceAll('Exception: ', '')),
                                    backgroundColor: AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isSaving = false);
                                }
                              }
                            },
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text('profile_save_changes'.tr),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.profileText,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: context.profileTextMuted)),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: context.profileBorder,
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final String? badge;
  final Widget? trailing;
  final VoidCallback onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    this.badge,
    this.trailing,
    required this.onTap,
  });
}

class _MenuTile extends StatelessWidget {
  final _MenuItem item;
  const _MenuTile({required this.item});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: context.isDarkProfile
                    ? AppColors.primary.withValues(alpha: 0.16)
                    : AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.profileText,
                ),
              ),
            ),
            if (item.badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  item.badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ] else if (item.trailing != null) ...[
              item.trailing!,
            ] else ...[
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: context.profileTextMuted),
            ],
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_rounded,
              size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Text('profile_verified'.tr,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.successText)),
        ],
      ),
    );
  }
}

class _UnverifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Text('profile_unverified'.tr,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warningText)),
        ],
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const _FormField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.profileTextSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          style: TextStyle(fontSize: 14, color: context.profileText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputHint.copyWith(
              color: context.profileTextMuted,
            ),
            prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: context.profileInputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide(color: context.profileBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide(color: context.profileBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
