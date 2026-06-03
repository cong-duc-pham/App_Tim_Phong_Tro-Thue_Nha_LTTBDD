import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../repositories/auth_repository.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSubmitting = false;

  // Trạng thái kiểm tra độ mạnh mật khẩu thời gian thực
  bool _hasMinLength = false;
  bool _hasNumber = false;
  bool _hasCapital = false;

  @override
  void initState() {
    super.initState();
    _newPwdCtrl.addListener(_onNewPasswordChanged);
  }

  @override
  void dispose() {
    _newPwdCtrl.removeListener(_onNewPasswordChanged);
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  void _onNewPasswordChanged() {
    final val = _newPwdCtrl.text;
    setState(() {
      _hasMinLength = val.length >= 8;
      _hasNumber = RegExp(r'[0-9]').hasMatch(val);
      _hasCapital = RegExp(r'[A-Z]').hasMatch(val);
    });
  }

  // Số lượng tiêu chí mật khẩu đã thỏa mãn
  int get _satisfiedCriteriaCount {
    int count = 0;
    if (_hasMinLength) count++;
    if (_hasNumber) count++;
    if (_hasCapital) count++;
    return count;
  }

  // Lấy màu sắc vạch đo độ mạnh mật khẩu
  Color get _strengthColor {
    final count = _satisfiedCriteriaCount;
    if (count == 3) return AppColors.success;
    if (count == 2) return AppColors.warning;
    if (count == 1) return AppColors.error;
    return const Color(0xFFE2E8F0); // Rỗng
  }

  String get _strengthText {
    final count = _satisfiedCriteriaCount;
    if (count == 3) return 'Mạnh';
    if (count == 2) return 'Trung bình';
    if (count == 1) return 'Yếu';
    return 'Chưa nhập';
  }

  // Giả lập đổi mật khẩu thực tế hoặc qua Firebase Auth
  Future<void> _submitChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    if (_satisfiedCriteriaCount < 3) {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mật khẩu mới chưa đạt yêu cầu bảo mật!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() {
      _isSubmitting = true;
    });

    final authRepo = AuthRepository();
    bool success = true;
    String errorMsg = '';

    try {
      // 1. Thực hiện đổi mật khẩu ở Backend trước
      await authRepo.changePassword(
        currentPassword: _currentPwdCtrl.text,
        newPassword: _newPwdCtrl.text.trim(),
      );

      // 2. Đồng thời nếu có tài khoản Firebase đang hoạt động, cập nhật song song để đồng bộ
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null && firebaseUser.email != null) {
        try {
          await firebaseUser.updatePassword(_newPwdCtrl.text.trim());
        } catch (_) {
          // Bỏ qua lỗi Firebase (chẳng hạn cần login gần đây)
          // vì đổi mật khẩu trên Backend đã thành công xuất sắc!
        }
      }
    } catch (e) {
      success = false;
      errorMsg = e.toString().replaceAll('Exception: ', '');
    }

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        HapticFeedback.mediumImpact();
        
        // Hiện SnackBar thành công
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Đổi mật khẩu thành công!', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
          ),
        );

        // Quay lại màn hình cá nhân
        context.pop();
      } else {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _satisfiedCriteriaCount;
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        title: const Text(
          'Đổi mật khẩu',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.borderLight, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mật khẩu hiện tại
              const Text(
                'Mật khẩu hiện tại',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _currentPwdCtrl,
                obscureText: _obscureCurrent,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập mật khẩu hiện tại';
                  }
                  return null;
                },
                decoration: _buildInputDecoration(
                  hintText: 'Nhập mật khẩu hiện tại',
                  obscureText: _obscureCurrent,
                  onToggleObscure: () {
                    setState(() => _obscureCurrent = !_obscureCurrent);
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Mật khẩu mới
              const Text(
                'Mật khẩu mới',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newPwdCtrl,
                obscureText: _obscureNew,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Vui lòng nhập mật khẩu mới';
                  }
                  if (val == _currentPwdCtrl.text) {
                    return 'Mật khẩu mới không được giống mật khẩu cũ';
                  }
                  return null;
                },
                decoration: _buildInputDecoration(
                  hintText: 'Nhập mật khẩu mới',
                  obscureText: _obscureNew,
                  onToggleObscure: () {
                    setState(() => _obscureNew = !_obscureNew);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Thanh hiển thị độ mạnh mật khẩu
              Row(
                children: [
                  const Text(
                    'Độ mạnh mật khẩu: ',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _strengthText,
                    style: TextStyle(fontSize: 12, color: _strengthColor, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(3, (index) {
                  final active = index < count;
                  return Expanded(
                    child: Container(
                      height: 5,
                      margin: EdgeInsets.only(
                        left: index > 0 ? 6 : 0,
                        right: index < 2 ? 6 : 0,
                      ),
                      decoration: BoxDecoration(
                        color: active ? _strengthColor : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 14),

              // Danh sách tiêu chuẩn bảo mật mật khẩu
              _buildCriteriaItem(label: 'Tối thiểu 8 ký tự', satisfied: _hasMinLength),
              const SizedBox(height: 6),
              _buildCriteriaItem(label: 'Chứa ít nhất 1 chữ số (0-9)', satisfied: _hasNumber),
              const SizedBox(height: 6),
              _buildCriteriaItem(label: 'Chứa ít nhất 1 chữ cái viết hoa (A-Z)', satisfied: _hasCapital),
              
              const SizedBox(height: 24),

              // Xác nhận mật khẩu mới
              const Text(
                'Xác nhận mật khẩu mới',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmPwdCtrl,
                obscureText: _obscureConfirm,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Vui lòng xác nhận mật khẩu mới';
                  }
                  if (val != _newPwdCtrl.text) {
                    return 'Mật khẩu xác nhận không trùng khớp';
                  }
                  return null;
                },
                decoration: _buildInputDecoration(
                  hintText: 'Nhập lại mật khẩu mới',
                  obscureText: _obscureConfirm,
                  onToggleObscure: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
              ),
              
              const SizedBox(height: 40),

              // Nút Submit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitChangePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Cập nhật mật khẩu',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleObscure,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      suffixIcon: IconButton(
        icon: Icon(
          obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.textMuted,
          size: 20,
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          onToggleObscure();
        },
      ),
    );
  }

  Widget _buildCriteriaItem({required String label, required bool satisfied}) {
    return Row(
      children: [
        Icon(
          satisfied ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: satisfied ? AppColors.success : AppColors.textMuted.withValues(alpha: 0.5),
          size: 15,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: satisfied ? FontWeight.w700 : FontWeight.w500,
            color: satisfied ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
