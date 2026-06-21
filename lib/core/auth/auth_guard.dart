// lib/core/auth/auth_guard.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// Utility tập trung kiểm tra trạng thái đăng nhập và hiện dialog yêu cầu đăng nhập.
class AuthGuard {
  const AuthGuard._();

  /// Trả về `true` nếu người dùng đã đăng nhập (có token hợp lệ trong SharedPreferences).
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    return token != null && token.trim().isNotEmpty;
  }

  /// Hiện bottom sheet thông báo yêu cầu đăng nhập.
  ///
  /// Trả về `true` nếu người dùng nhấn "Đăng nhập ngay" và điều hướng đi,
  /// trả về `false` nếu người dùng nhấn "Để sau".
  static Future<bool> showLoginRequired(
    BuildContext context, {
    String? featureName,
  }) async {
    if (!context.mounted) return false;

    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _LoginRequiredSheet(featureName: featureName),
    );

    return result == true;
  }

  /// Kiểm tra đăng nhập và nếu chưa thì hiện dialog.
  ///
  /// Trả về `true` nếu đã đăng nhập (được tiếp tục hành động).
  /// Trả về `false` nếu chưa đăng nhập (đã hiện dialog, hành động bị chặn).
  static Future<bool> checkAndPrompt(
    BuildContext context, {
    String? featureName,
  }) async {
    final loggedIn = await isLoggedIn();
    if (loggedIn) return true;
    if (context.mounted) {
      await showLoginRequired(context, featureName: featureName);
    }
    return false;
  }
}

class _LoginRequiredSheet extends StatelessWidget {
  final String? featureName;

  const _LoginRequiredSheet({this.featureName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final borderColor = isDark ? const Color(0xFF334155) : AppColors.border;

    String title = 'Yêu cầu đăng nhập';
    String description = featureName != null
        ? 'Bạn cần đăng nhập để sử dụng tính năng "$featureName".'
        : 'Bạn cần đăng nhập để sử dụng tính năng này.';

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXxl),
        ),
        border: Border.all(color: borderColor),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
          ),
          const SizedBox(height: 24),

          // Icon
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),

          // Description
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: subColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // Nút Đăng nhập ngay
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop(true);
                context.push(AppConstants.routeLogin);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
              ),
              icon: const Icon(Icons.login_rounded, size: 20),
              label: const Text(
                'Đăng nhập ngay',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Nút Để sau
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  side: BorderSide(color: borderColor),
                ),
              ),
              child: Text(
                'Để sau',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: subColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
