// lib/screens/profile/settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/auth/logout_helper.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../services/search_history_service.dart';
import '../../core/localization/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Trạng thái các cài đặt
  ThemeMode _themeMode = ThemeMode.light;
  bool _notificationsEnabled = true;
  String _language = 'vi';

  // Trạng thái dọn dẹp dữ liệu
  double _cacheSize = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Tải cài đặt từ SharedPreferences và kích thước cache
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();

    // Đọc ThemeMode
    final themeStr = prefs.getString(AppConstants.keyThemeMode) ?? 'light';
    ThemeMode savedTheme = ThemeMode.light;
    if (themeStr == 'dark') {
      savedTheme = ThemeMode.dark;
    } else if (themeStr == 'system') {
      savedTheme = ThemeMode.system;
    }

    // Đọc Thông báo
    final notifsEnabled =
        prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true;

    // Đọc Ngôn ngữ
    final lang = prefs.getString(AppConstants.keyAppLanguage) ?? 'vi';

    // Tính kích thước Cache thực tế
    final size = await _calculateCacheSize();

    setState(() {
      _themeMode = savedTheme;
      _notificationsEnabled = notifsEnabled;
      _language = lang;
      _cacheSize = size;
      _isLoading = false;
    });
  }

  // Tính toán kích thước bộ nhớ đệm
  Future<double> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      return _getDirectorySize(tempDir);
    } catch (e) {
      return 0;
    }
  }

  double _getDirectorySize(FileSystemEntity file) {
    if (file is File) {
      return file.lengthSync().toDouble();
    } else if (file is Directory) {
      double total = 0;
      try {
        final List<FileSystemEntity> children = file.listSync(recursive: true);
        for (final FileSystemEntity child in children) {
          if (child is File) {
            total += child.lengthSync();
          }
        }
      } catch (_) {}
      return total;
    }
    return 0;
  }

  // Lưu cấu hình Theme và cập nhật thời gian thực
  Future<void> _changeTheme(ThemeMode mode) async {
    await saveThemeMode(mode);
    setState(() {
      _themeMode = mode;
    });

    HapticFeedback.mediumImpact();
  }

  // Thay đổi cài đặt bật/tắt thông báo
  Future<void> _toggleNotifications(bool value) async {
    await saveNotificationsEnabled(value);
    setState(() {
      _notificationsEnabled = value;
    });
    HapticFeedback.lightImpact();
  }

  // Thay đổi ngôn ngữ
  Future<void> _changeLanguage(String langCode) async {
    await saveAppLanguage(langCode);

    setState(() {
      _language = langCode;
    });
    HapticFeedback.mediumImpact();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('lang_changed_snack'.tr),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // Xóa lịch sử tìm kiếm gần đây
  Future<void> _clearSearchHistory() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text(
          'clear_search_confirm_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'clear_search_confirm_desc'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await SearchHistoryService.clearHistory();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('clear_search_success'.tr),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('clear'.tr),
          ),
        ],
      ),
    );
  }

  // Dọn dẹp cache ứng dụng
  Future<void> _clearAppCache() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text(
          'clear_cache_confirm_title'.tr,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'clear_cache_confirm_desc'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);

              try {
                final tempDir = await getTemporaryDirectory();
                if (tempDir.existsSync()) {
                  final List<FileSystemEntity> children = tempDir.listSync();
                  for (final FileSystemEntity child in children) {
                    try {
                      child.deleteSync(recursive: true);
                    } catch (_) {}
                  }
                }
              } catch (_) {}

              final size = await _calculateCacheSize();
              if (!mounted) return;
              setState(() {
                _cacheSize = size;
                _isLoading = false;
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('clear_cache_success'.tr),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('dialog_clean'.tr),
          ),
        ],
      ),
    );
  }

  // Xác nhận vô hiệu hóa tài khoản
  void _confirmDeactivateAccount() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text(
          'deactivate_confirm_title'.tr,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.error),
        ),
        content: Text(
          'deactivate_confirm_desc'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await LogoutHelper.signOutAndGoToLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('deactivate_confirm_btn'.tr),
          ),
        ],
      ),
    );
  }

  // Định dạng hiển thị kích thước
  String _formatSize(double bytes) {
    if (bytes <= 0) return '0 KB';
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.bgPage,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    children: [
                      // Section: Giao diện
                      _buildSectionTitle('interface_section'.tr),
                      _buildSettingsCard([
                        _buildThemeSelectorTile(),
                        _buildDivider(),
                        _buildSwitchTile(
                          icon: Icons.notifications_active_outlined,
                          title: 'push_notifications'.tr,
                          subtitle: 'notifications_desc'.tr,
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                        ),
                        _buildDivider(),
                        _buildLanguageSelectorTile(),
                      ]),

                      const SizedBox(height: 20),

                      // Section: Dọn dẹp dữ liệu
                      _buildSectionTitle('data_section'.tr),
                      _buildSettingsCard([
                        _buildActionTile(
                          icon: Icons.history_rounded,
                          title: 'clear_search'.tr,
                          subtitle: 'clear_search_desc'.tr,
                          onTap: _clearSearchHistory,
                        ),
                        _buildDivider(),
                        _buildActionTile(
                          icon: Icons.cleaning_services_outlined,
                          title: 'clear_cache'.tr,
                          subtitle: 'clear_cache_desc'.tr,
                          trailing: Text(
                            _formatSize(_cacheSize),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onTap: _clearAppCache,
                        ),
                      ]),

                      const SizedBox(height: 20),

                      // Section: Tài khoản
                      _buildSectionTitle('account_section'.tr),
                      _buildSettingsCard([
                        _buildActionTile(
                          icon: Icons.lock_open_rounded,
                          title: 'change_password'.tr,
                          subtitle: 'change_password_desc'.tr,
                          onTap: () =>
                              context.push(AppConstants.routeChangePassword),
                        ),
                        _buildDivider(),
                        _buildActionTile(
                          icon: Icons.no_accounts_outlined,
                          title: 'deactivate_account'.tr,
                          subtitle: 'deactivate_account_desc'.tr,
                          titleColor: AppColors.error,
                          onTap: _confirmDeactivateAccount,
                        ),
                      ]),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Header đồng bộ với các màn hình con trong Profile
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
                    onTap: () => context.pop(),
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
                    'settings_title'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0F172A)
                    : AppColors.bgPage,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(
          color: isDark ? Colors.white10 : AppColors.borderLight,
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      color: isDark ? Colors.white10 : AppColors.borderLight,
      indent: 52,
    );
  }

  // Tùy chọn giao diện (Theme Selector)
  Widget _buildThemeSelectorTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String themeLabel = 'theme_light'.tr;
    if (_themeMode == ThemeMode.dark) {
      themeLabel = 'theme_dark'.tr;
    } else if (_themeMode == ThemeMode.system) {
      themeLabel = 'theme_system'.tr;
    }

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : AppColors.bgCardLight,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _themeMode == ThemeMode.dark
              ? Icons.dark_mode_outlined
              : _themeMode == ThemeMode.light
                  ? Icons.light_mode_outlined
                  : Icons.settings_brightness_outlined,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        'app_theme'.tr,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${'theme_mode_active'.tr}$themeLabel',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: DropdownButton<ThemeMode>(
        value: _themeMode,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
        onChanged: (mode) {
          if (mode != null) _changeTheme(mode);
        },
        items: [
          DropdownMenuItem(
            value: ThemeMode.light,
            child: Text('theme_light'.tr),
          ),
          DropdownMenuItem(
            value: ThemeMode.dark,
            child: Text('theme_dark'.tr),
          ),
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('theme_system'.tr),
          ),
        ],
      ),
    );
  }

  // Tùy chọn ngôn ngữ (Language Selector)
  Widget _buildLanguageSelectorTile() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String langLabel = _language == 'vi' ? 'lang_vi'.tr : 'lang_en'.tr;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : AppColors.bgCardLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.language_rounded,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        'language'.tr,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${'lang_active'.tr}$langLabel',
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: DropdownButton<String>(
        value: _language,
        underline: const SizedBox.shrink(),
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textMuted),
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : AppColors.textPrimary,
        ),
        onChanged: (langCode) {
          if (langCode != null) _changeLanguage(langCode);
        },
        items: [
          DropdownMenuItem(
            value: 'vi',
            child: Text('lang_vi'.tr),
          ),
          DropdownMenuItem(
            value: 'en',
            child: Text('lang_en'.tr),
          ),
        ],
      ),
    );
  }

  // Tile dạng Switch (Bật/Tắt)
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : AppColors.bgCardLight,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Switch.adaptive(
        value: value,
        activeThumbColor: AppColors.primary,
        onChanged: onChanged,
      ),
    );
  }

  // Tile dạng Button hành động
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? titleColor,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : AppColors.bgCardLight,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: titleColor ?? AppColors.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: titleColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: trailing ??
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 14,
            color: AppColors.textMuted,
          ),
    );
  }
}
