import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../repositories/password_reset_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _repository = PasswordResetRepository();

  bool _isLoading = false;
  bool _otpSent = false;
  bool _resetDone = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _resendCountdown = 0;
  Timer? _timer;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown == 0) {
        timer.cancel();
      } else if (mounted) {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      await _repository.requestOtp(_emailCtrl.text);
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      _animController.reset();
      setState(() => _otpSent = true);
      _animController.forward();
      _startCountdown();
    } catch (e) {
      if (mounted) _showError(_cleanException(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _submitResetPassword() async {
    if (!_otpFormKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      await _repository.resetPassword(
        email: _emailCtrl.text,
        otpCode: _otpCtrl.text,
        newPassword: _newPasswordCtrl.text,
      );
      if (!mounted) return;

      HapticFeedback.mediumImpact();
      _timer?.cancel();
      _animController.reset();
      setState(() => _resetDone = true);
      _animController.forward();
    } catch (e) {
      if (mounted) _showError(_cleanException(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
      ),
    );
  }

  String _cleanException(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingH,
                vertical: AppConstants.spacingLg,
              ),
              child: _resetDone
                  ? _buildResetDoneState()
                  : (_otpSent ? _buildOtpState() : _buildInputState()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderIcon(Icons.lock_reset_rounded),
          const SizedBox(height: 28),
          Text('Quên mật khẩu?', style: AppTextStyles.h1),
          const SizedBox(height: 8),
          Text(
            'Nhập email đã đăng ký bằng mật khẩu. Swings House sẽ gửi mã OTP để bạn đặt lại mật khẩu.',
            style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
          ),
          const SizedBox(height: 36),
          Text('Email tài khoản', style: AppTextStyles.inputLabel),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _emailCtrl,
            hintText: 'example@email.com',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
              if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(v.trim())) {
                return 'Email không hợp lệ';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Gửi mã OTP',
            onPressed: _isLoading ? null : _submitRequest,
          ),
          const SizedBox(height: 24),
          Center(child: _buildBackToLoginButton()),
        ],
      ),
    );
  }

  Widget _buildOtpState() {
    return Form(
      key: _otpFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderIcon(Icons.mark_email_read_rounded),
          const SizedBox(height: 28),
          Text('Nhập mã OTP', style: AppTextStyles.h1),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(
                height: 1.45,
                color: AppColors.textSecondary,
              ),
              children: [
                const TextSpan(text: 'Mã OTP đã được gửi đến '),
                TextSpan(
                  text: _emailCtrl.text.trim(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const TextSpan(text: '. Mã có hiệu lực trong 10 phút.'),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text('Mã OTP', style: AppTextStyles.inputLabel),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _otpCtrl,
            hintText: '123456',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.pin_outlined,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Vui lòng nhập OTP';
              if (v.trim().length < 4) return 'OTP không hợp lệ';
              return null;
            },
          ),
          const SizedBox(height: 18),
          Text('Mật khẩu mới', style: AppTextStyles.inputLabel),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _newPasswordCtrl,
            hintText: 'Tối thiểu 6 ký tự',
            prefixIcon: Icons.lock_outline_rounded,
            obscureText: _obscureNewPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () {
                setState(() => _obscureNewPassword = !_obscureNewPassword);
              },
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu mới';
              if (v.length < 6) return 'Mật khẩu cần tối thiểu 6 ký tự';
              return null;
            },
          ),
          const SizedBox(height: 18),
          Text('Nhập lại mật khẩu', style: AppTextStyles.inputLabel),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _confirmPasswordCtrl,
            hintText: 'Nhập lại mật khẩu mới',
            prefixIcon: Icons.lock_reset_rounded,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: AppColors.textMuted,
                size: 20,
              ),
              onPressed: () {
                setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                );
              },
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Vui lòng nhập lại mật khẩu';
              if (v != _newPasswordCtrl.text) return 'Mật khẩu không khớp';
              return null;
            },
          ),
          const SizedBox(height: 28),
          _buildPrimaryButton(
            label: 'Đặt lại mật khẩu',
            onPressed: _isLoading ? null : _submitResetPassword,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed:
                  _resendCountdown > 0 || _isLoading ? null : _submitRequest,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.borderLight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                ),
              ),
              child: Text(
                _resendCountdown > 0
                    ? 'Gửi lại sau ${_resendCountdown}s'
                    : 'Gửi lại OTP',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: _buildBackToLoginButton()),
        ],
      ),
    );
  }

  Widget _buildResetDoneState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 54,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Đặt lại mật khẩu thành công',
          style: AppTextStyles.h1.copyWith(fontSize: 22),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Bạn có thể đăng nhập lại bằng mật khẩu mới vừa tạo.',
          style: AppTextStyles.bodyMedium.copyWith(
            height: 1.5,
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        _buildPrimaryButton(
          label: 'Quay lại đăng nhập',
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
      ],
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textMuted,
        ),
        prefixIcon: Icon(prefixIcon, color: AppColors.textMuted, size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Widget _buildBackToLoginButton() {
    return TextButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        context.pop();
      },
      child: Text(
        'Quay lại đăng nhập',
        style: AppTextStyles.btnSecondary.copyWith(fontSize: 13.5),
      ),
    );
  }
}
