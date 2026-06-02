// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
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
  });
}

// Dữ liệu mẫu — thay bằng API call thật
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

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(AppConstants.keyUserToken);
    final savedUserId = prefs.getString(AppConstants.keyUserId);
    if (savedToken != null &&
        savedToken.isNotEmpty &&
        savedUserId != null &&
        savedUserId.isNotEmpty) {
      final savedEmail = prefs.getString('user_email') ?? '';
      final savedFullName = prefs.getString('user_full_name');
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
          phone: '',
          role: effectiveRole,
          isVerified: isVerifyMain,
          createdAt: DateTime.now(),
          listingsCount: listingsCount,
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
      phone: firebaseUser.phoneNumber ?? '',
      role: 'tenant',
      isVerified: firebaseUser.emailVerified,
      avatarUrl: firebaseUser.photoURL,
      createdAt: firebaseUser.metadata.creationTime ?? DateTime.now(),
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
          phone: (data['phone'] as String?) ?? firebaseUser.phoneNumber ?? '',
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoading();
    if (!_isLoggedIn) return _buildNotLoggedIn();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildStats()),
          SliverToBoxAdapter(
              child: _buildMenuSection(
            title: 'Tài khoản',
            items: [
              _MenuItem(
                icon: Icons.person_outline_rounded,
                label: 'Thông tin cá nhân',
                onTap: () => _showEditProfile(),
              ),
              _MenuItem(
                icon: Icons.lock_outline_rounded,
                label: 'Đổi mật khẩu',
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppConstants.routeChangePassword);
                },
              ),
              _MenuItem(
                icon: Icons.verified_user_outlined,
                label: 'Xác thực tài khoản',
                trailing:
                    _user.isVerified ? _VerifiedBadge() : _UnverifiedBadge(),
                onTap: () async {
                  await context.push(AppConstants.routeVerifyAccount);
                  _loadCurrentUser();
                },
              ),
              _MenuItem(
                icon: Icons.tune_rounded,
                label: 'Nhu cầu tìm phòng',
                onTap: () {
                  context.push('${AppConstants.routePreference}?from=profile');
                },
              ),
            ],
          )),
          SliverToBoxAdapter(
              child: _buildMenuSection(
            title: 'Hoạt động',
            items: [
              _MenuItem(
                icon: Icons.favorite_border_rounded,
                label: 'Phòng đã lưu',
                badge:
                    _user.favoritesCount > 0 ? '${_user.favoritesCount}' : null,
                onTap: () => context.push(AppConstants.routeFavorites),
              ),
              _MenuItem(
                icon: Icons.rate_review_outlined,
                label: 'Đánh giá của tôi',
                badge: _user.reviewsCount > 0 ? '${_user.reviewsCount}' : null,
                onTap: () => context.push(AppConstants.routeMyReviews),
              ),
              _MenuItem(
                icon: Icons.history_rounded,
                label: 'Lịch sử tìm kiếm',
                onTap: () => context.push(AppConstants.routeSearchHistory),
              ),
              if (_user.role == 'landlord') ...[
                _MenuItem(
                  icon: Icons.home_work_outlined,
                  label: 'Tin đăng của tôi',
                  badge:
                      _user.listingsCount > 0 ? '${_user.listingsCount}' : null,
                  onTap: () => context.push(AppConstants.routeMyListings),
                ),
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Hóa đơn & Thanh toán',
                  onTap: () {},
                ),
              ],
            ],
          )),
          SliverToBoxAdapter(
              child: _buildMenuSection(
            title: 'Hỗ trợ',
            items: [
              _MenuItem(
                icon: Icons.help_outline_rounded,
                label: 'Trung tâm hỗ trợ',
                onTap: () => context.push(AppConstants.routeSupportCenter),
              ),
              _MenuItem(
                icon: Icons.bug_report_outlined,
                label: 'Báo cáo sự cố',
                onTap: () => context.push(AppConstants.routeReportIssue),
              ),
              _MenuItem(
                icon: Icons.star_border_rounded,
                label: 'Đánh giá ứng dụng',
                onTap: () {},
              ),
              _MenuItem(
                icon: Icons.info_outline_rounded,
                label: 'Về ứng dụng',
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
                  const Text(
                    'Cá nhân',
                    style: TextStyle(
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
                        _user.role == 'landlord' ? 'Chủ nhà' : 'Người thuê',
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text(
                          'Đã xác thực',
                          style: TextStyle(
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
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          _StatItem(
            value: '${_user.favoritesCount}',
            label: 'Yêu thích',
            icon: Icons.favorite_rounded,
            color: AppColors.error,
          ),
          _Divider(),
          _StatItem(
            value: _formatJoinDate(_user.createdAt),
            label: 'Ngày tham gia',
            icon: Icons.calendar_today_rounded,
            color: AppColors.primary,
          ),
          _Divider(),
          _StatItem(
            value: '${_user.reviewsCount}',
            label: 'Đánh giá',
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
                color: AppColors.textMuted,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return Column(
                  children: [
                    _MenuTile(item: item),
                    if (i < items.length - 1)
                      const Divider(
                        height: 1,
                        color: AppColors.borderLight,
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
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                'Đăng xuất',
                style: TextStyle(
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
    return const Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }

  Widget _buildNotLoggedIn() {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: const Row(
                children: [
                  Text(
                    'Cá nhân',
                    style: TextStyle(
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
                      const Text(
                        'Chưa đăng nhập',
                        style: AppTextStyles.h2,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Đăng nhập để xem thông tin cá nhân,\nphòng đã lưu và nhiều tính năng khác',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => context.go(AppConstants.routeLogin),
                          child: const Text('Đăng nhập ngay'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              context.go(AppConstants.routeRegister),
                          child: const Text('Tạo tài khoản mới'),
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        title: const Text('Đăng xuất?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content:
            const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove(AppConstants.keyUserToken);
              await prefs.remove(AppConstants.keyUserId);
              await prefs.remove(AppConstants.keyUserRole);
              await prefs.remove('refresh_token');
              await prefs.remove('user_email');
              await prefs.remove('user_full_name');
              if (!mounted) return;
              setState(() => _isLoggedIn = false);
              context.go(AppConstants.routeLogin);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đăng xuất'),
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppConstants.radiusXxl)),
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text('Chỉnh sửa thông tin',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 20, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _FormField(
                    ctrl: _nameCtrl,
                    label: 'Họ và tên',
                    hint: 'Nhập họ và tên',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    ctrl: _phoneCtrl,
                    label: 'Số điện thoại',
                    hint: '0901 234 567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
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
                                  const SnackBar(
                                    content: Text('Họ và tên không được để trống'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                                return;
                              }

                              setState(() => _isSaving = true);
                              try {
                                await AuthRepository().updateProfile(
                                  fullName: name,
                                  phone: phone,
                                );
                                if (!mounted) return;
                                widget.onSaved();
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Đã cập nhật thông tin thành công'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
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
                          : const Text('Lưu thay đổi'),
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
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.textMuted)),
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
      color: AppColors.borderLight,
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
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
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
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textMuted),
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
          SizedBox(width: 4),
          Text('Đã xác thực',
              style: TextStyle(
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.warning),
          SizedBox(width: 4),
          Text('Chưa xác thực',
              style: TextStyle(
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

  const _FormField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.inputHint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
            filled: true,
            fillColor: AppColors.bgPage,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.border),
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
