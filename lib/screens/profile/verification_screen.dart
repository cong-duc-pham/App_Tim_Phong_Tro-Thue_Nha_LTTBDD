import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';

class AccountVerificationScreen extends StatefulWidget {
  const AccountVerificationScreen({super.key});

  @override
  State<AccountVerificationScreen> createState() =>
      _AccountVerificationScreenState();
}

class _AccountVerificationScreenState extends State<AccountVerificationScreen> {
  bool _isLoading = true;

  // Trạng thái xác thực các cổng
  bool _emailVerified = false;
  String _emailAddress = '';

  bool _phoneVerified = false;
  String _phoneNumber = '';

  bool _googleLinked = false;
  String _googleEmail = '';

  bool _facebookLinked = false;
  String _facebookName = '';

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Đọc trạng thái Email
    if (firebaseUser != null) {
      _emailVerified = firebaseUser.emailVerified;
      _emailAddress = firebaseUser.email ?? '';
    } else {
      _emailVerified = prefs.getBool('verify_email_status') ?? false;
      _emailAddress =
          prefs.getString('verify_email_address') ?? 'duc.pham@example.com';
    }

    // Đọc trạng thái Số điện thoại
    _phoneVerified = prefs.getBool('verify_phone_status') ?? false;
    _phoneNumber = prefs.getString('verify_phone_number') ?? '';
    if (!_phoneVerified &&
        firebaseUser != null &&
        firebaseUser.phoneNumber != null &&
        firebaseUser.phoneNumber!.isNotEmpty) {
      _phoneVerified = true;
      _phoneNumber = firebaseUser.phoneNumber!;
    }

    // Đọc trạng thái liên kết Google/Facebook từ SharedPreferences
    _googleLinked = prefs.getBool('link_google_status') ?? false;
    _googleEmail = prefs.getString('link_google_email') ?? '';

    _facebookLinked = prefs.getBool('link_facebook_status') ?? false;
    _facebookName = prefs.getString('link_facebook_name') ?? '';

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Tính toán mức độ tin cậy động (Trust Level)
  double get _trustScore {
    double score = 0;
    if (_emailVerified) score += 0.25;
    if (_phoneVerified) score += 0.25;
    if (_googleLinked) score += 0.25;
    if (_facebookLinked) score += 0.25;
    return score;
  }

  String get _trustLevelText {
    final score = _trustScore;
    if (score == 1.0) return 'verify_trust_level_absolute'.tr;
    if (score >= 0.75) return 'verify_trust_level_high'.tr;
    if (score >= 0.5) return 'verify_trust_level_medium'.tr;
    return 'verify_trust_level_low'.tr;
  }

  Color get _trustColor {
    final score = _trustScore;
    if (score == 1.0) return AppColors.success;
    if (score >= 0.75) return Colors.teal;
    if (score >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  // Giả lập gửi email xác minh
  Future<void> _verifyEmail() async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        await firebaseUser.sendEmailVerification();
      } catch (_) {}
    }

    await Future.delayed(const Duration(seconds: 1500));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('verify_email_status', true);
    await prefs.setString('verify_email_address',
        _emailAddress.isNotEmpty ? _emailAddress : 'duc.pham@example.com');

    // Đồng bộ cả flag isVerified chung của hệ thống khi đã xác thực email
    await prefs.setBool(
        'verify_account_main_status', _trustScore + 0.25 >= 1.0);

    await _loadVerificationStatus();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('verify_email_sent_mock'.tr),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Giả lập liên kết Google
  Future<void> _toggleGoogle() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();

    if (_googleLinked) {
      // Hủy liên kết
      final confirm = await _showConfirmDialog(
        title: 'verify_confirm_unlink_google_title'.tr,
        content: 'verify_confirm_unlink_google_desc'.tr,
      );
      if (confirm == true) {
        setState(() => _isLoading = true);
        await Future.delayed(const Duration(milliseconds: 800));
        await prefs.setBool('link_google_status', false);
        await prefs.setString('link_google_email', '');
        await prefs.setBool('verify_account_main_status', false);
        await _loadVerificationStatus();
        HapticFeedback.mediumImpact();
      }
    } else {
      // Liên kết mới
      setState(() => _isLoading = true);
      await Future.delayed(
          const Duration(seconds: 1500)); // Giả lập loading popup
      await prefs.setBool('link_google_status', true);
      await prefs.setString('link_google_email',
          _emailAddress.isNotEmpty ? _emailAddress : 'duc.pham@gmail.com');

      final nextScore = _trustScore + 0.25;
      await prefs.setBool('verify_account_main_status', nextScore >= 1.0);

      await _loadVerificationStatus();
      HapticFeedback.mediumImpact();
      _showSuccessSnackBar('verify_success_google_link'.tr);
    }
  }

  // Giả lập liên kết Facebook
  Future<void> _toggleFacebook() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();

    if (_facebookLinked) {
      // Hủy liên kết
      final confirm = await _showConfirmDialog(
        title: 'verify_confirm_unlink_facebook_title'.tr,
        content: 'verify_confirm_unlink_facebook_desc'.tr,
      );
      if (confirm == true) {
        setState(() => _isLoading = true);
        await Future.delayed(const Duration(milliseconds: 800));
        await prefs.setBool('link_facebook_status', false);
        await prefs.setString('link_facebook_name', '');
        await prefs.setBool('verify_account_main_status', false);
        await _loadVerificationStatus();
        HapticFeedback.mediumImpact();
      }
    } else {
      // Liên kết mới
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(seconds: 1500));
      await prefs.setBool('link_facebook_status', true);
      await prefs.setString('link_facebook_name', 'Đức Phạm (Facebook)');

      final nextScore = _trustScore + 0.25;
      await prefs.setBool('verify_account_main_status', nextScore >= 1.0);

      await _loadVerificationStatus();
      HapticFeedback.mediumImpact();
      _showSuccessSnackBar('verify_success_facebook_link'.tr);
    }
  }

  // Mở Bottom Sheet xác thực số điện thoại
  void _openPhoneVerificationSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PhoneVerificationSheet(
        onSuccess: (phone) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('verify_phone_status', true);
          await prefs.setString('verify_phone_number', phone);

          final nextScore = _trustScore + 0.25;
          await prefs.setBool('verify_account_main_status', nextScore >= 1.0);

          await _loadVerificationStatus();
          _showSuccessSnackBar('verify_success_phone_verify'.tr);
        },
      ),
    );
  }

  void _showSuccessSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      ),
    );
  }

  Future<bool?> _showConfirmDialog(
      {required String title, required String content}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.profileCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: context.profileText)),
        content: Text(content,
            style: TextStyle(
                fontSize: 14,
                color: context.profileTextSecondary,
                height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('verify_dialog_cancel'.tr,
                style: const TextStyle(
                    color: AppColors.textMuted, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
            ),
            child: Text('verify_action_unlink'.tr,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      appBar: AppBar(
        backgroundColor: context.profileCard,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: context.profileText, size: 18),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        title: Text(
          'profile_verify_account'.tr,
          style: TextStyle(
              color: context.profileText,
              fontSize: 18,
              fontWeight: FontWeight.w800),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: context.profileBorder, height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTrustMeterCard(),
                  const SizedBox(height: 28),
                  Text(
                    'verify_gateways_title'.tr,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: context.profileText),
                  ),
                  const SizedBox(height: 12),
                  _buildVerificationItem(
                    icon: Icons.email_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF185FA5),
                    title: 'verify_email'.tr,
                    subtitle: _emailAddress.isNotEmpty
                        ? _emailAddress
                        : 'verify_email_unlinked'.tr,
                    isVerified: _emailVerified,
                    actionText: _emailVerified
                        ? 'verify_email_verified'.tr
                        : 'verify_email_verify_now'.tr,
                    onTap: _emailVerified ? null : _verifyEmail,
                  ),
                  const SizedBox(height: 12),
                  _buildVerificationItem(
                    icon: Icons.phone_android_rounded,
                    iconBg: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF166534),
                    title: 'verify_phone'.tr,
                    subtitle: _phoneVerified
                        ? _phoneNumber
                        : 'verify_phone_unverified'.tr,
                    isVerified: _phoneVerified,
                    actionText: _phoneVerified
                        ? 'verify_phone_verified'.tr
                        : 'verify_phone_verify_now'.tr,
                    onTap: _phoneVerified ? null : _openPhoneVerificationSheet,
                  ),
                  const SizedBox(height: 12),
                  _buildVerificationItem(
                    icon: Icons.g_mobiledata_rounded,
                    iconBg: const Color(0xFFFEF2F2),
                    iconColor: const Color(0xFFDC2626),
                    title: 'verify_google'.tr,
                    subtitle:
                        _googleLinked ? _googleEmail : 'verify_google_desc'.tr,
                    isVerified: _googleLinked,
                    actionText: _googleLinked
                        ? 'verify_action_unlink'.tr
                        : 'verify_action_link'.tr,
                    actionColor:
                        _googleLinked ? AppColors.textMuted : AppColors.primary,
                    onTap: _toggleGoogle,
                  ),
                  const SizedBox(height: 12),
                  _buildVerificationItem(
                    icon: Icons.facebook_rounded,
                    iconBg: const Color(0xFFF0F9FF),
                    iconColor: const Color(0xFF0284C7),
                    title: 'verify_facebook'.tr,
                    subtitle: _facebookLinked
                        ? _facebookName
                        : 'verify_facebook_desc'.tr,
                    isVerified: _facebookLinked,
                    actionText: _facebookLinked
                        ? 'verify_action_unlink'.tr
                        : 'verify_action_link'.tr,
                    actionColor: _facebookLinked
                        ? AppColors.textMuted
                        : AppColors.primary,
                    onTap: _toggleFacebook,
                  ),
                  const SizedBox(height: 24),
                  _buildSecurityTipCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildTrustMeterCard() {
    final score = _trustScore;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _trustColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  score == 1.0 ? Icons.verified_rounded : Icons.shield_rounded,
                  color: _trustColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'verify_trust_title'.tr,
                      style: TextStyle(
                          fontSize: 13,
                          color: context.profileTextSecondary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'verify_trust_level_label'
                              .tr
                              .replaceAll('{level}', _trustLevelText),
                          style: TextStyle(
                              fontSize: 18,
                              color: _trustColor,
                              fontWeight: FontWeight.w800),
                        ),
                        if (score == 1.0) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 16),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${(score * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: context.profileText),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 8,
              backgroundColor: context.profileBorder,
              valueColor: AlwaysStoppedAnimation<Color>(_trustColor),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            score == 1.0
                ? 'verify_trust_success_desc'.tr
                : 'verify_trust_warning_desc'.tr,
            style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: context.profileTextSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isVerified,
    required String actionText,
    Color? actionColor,
    VoidCallback? onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.profileText),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isVerified
                        ? context.profileTextSecondary
                        : context.profileTextMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (onTap == null)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 16),
                const SizedBox(width: 4),
                Text(
                  actionText,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700),
                ),
              ],
            )
          else
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: actionColor ?? AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusFull)),
                ),
                child: Text(
                  actionText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: actionColor ?? AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSecurityTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.profileBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'verify_security_commitment'.tr,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: context.profileTextSecondary,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet xác thực số điện thoại & OTP ─────────────────────────────
class _PhoneVerificationSheet extends StatefulWidget {
  final Function(String) onSuccess;
  const _PhoneVerificationSheet({required this.onSuccess});

  @override
  State<_PhoneVerificationSheet> createState() =>
      _PhoneVerificationSheetState();
}

class _PhoneVerificationSheetState extends State<_PhoneVerificationSheet> {
  final TextEditingController _phoneCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocuses = List.generate(6, (_) => FocusNode());

  bool _otpSent = false;
  int _countdown = 60;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (var c in _otpCtrls) {
      c.dispose();
    }
    for (var f in _otpFocuses) {
      f.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() {
      _countdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        timer.cancel();
      } else {
        setState(() {
          _countdown--;
        });
      }
    });
  }

  void _sendOtp() {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('verify_otp_invalid_phone'.tr)),
      );
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _otpSent = true;
    });
    _startTimer();
    // Tự động focus ô OTP đầu tiên sau khi chuyển giao diện
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _otpFocuses[0].requestFocus();
    });
  }

  void _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('verify_otp_invalid_otp'.tr)),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isVerifying = true;
    });

    // Giả lập xác thực OTP
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isVerifying = false;
      });
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      widget.onSuccess(_phoneCtrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.only(top: 80),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 30),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.profileBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _otpSent ? 'verify_otp_title'.tr : 'verify_phone_verify_now'.tr,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: context.profileText),
            ),
            const SizedBox(height: 6),
            Text(
              _otpSent
                  ? 'verify_otp_sent_to'
                      .tr
                      .replaceAll('{phone}', _phoneCtrl.text)
                  : 'verify_otp_instruction'.tr,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: context.profileTextSecondary,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            if (!_otpSent) ...[
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.profileText),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: const Icon(Icons.phone_rounded,
                      color: AppColors.primary, size: 20),
                  hintText: 'verify_phone_input_hint'.tr,
                  hintStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.profileTextMuted),
                  filled: true,
                  fillColor: context.profileBg,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    borderSide: BorderSide(color: context.profileBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _sendOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLg)),
                    elevation: 0,
                  ),
                  child: Text('verify_otp_get_code'.tr,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 44,
                    height: 50,
                    child: TextField(
                      controller: _otpCtrls[index],
                      focusNode: _otpFocuses[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: context.profileBg,
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: BorderSide(color: context.profileBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          if (index < 5) {
                            _otpFocuses[index + 1].requestFocus();
                          } else {
                            _otpFocuses[index].unfocus();
                          }
                        } else {
                          if (index > 0) {
                            _otpFocuses[index - 1].requestFocus();
                          }
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _countdown > 0
                        ? 'verify_otp_resend_countdown'
                            .tr
                            .replaceAll('{seconds}', '$_countdown')
                        : 'verify_otp_not_received'.tr,
                    style: TextStyle(
                        fontSize: 13,
                        color: context.profileTextSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  if (_countdown == 0)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _startTimer();
                      },
                      child: Text(
                        'verify_otp_resend_now'.tr,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isVerifying ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusLg)),
                    elevation: 0,
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text('verify_otp_confirm'.tr,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
