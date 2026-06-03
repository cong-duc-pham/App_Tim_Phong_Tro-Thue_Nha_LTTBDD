import 'package:flutter/material.dart';

/// Global notifier for application language.
/// Defaults to Vietnamese ('vi').
final ValueNotifier<String> languageNotifier = ValueNotifier('vi');

/// Reactive translation system for Swings House.
class AppLocalizations {
  AppLocalizations._();

  static final Map<String, Map<String, String>> _localizedValues = {
    'vi': {
      'settings_title': 'Cài đặt hệ thống',
      'interface_section': 'GIAO DIỆN & CẤU HÌNH',
      'app_theme': 'Giao diện ứng dụng',
      'theme_mode_active': 'Đang áp dụng: ',
      'theme_light': 'Sáng',
      'theme_dark': 'Tối',
      'theme_system': 'Hệ thống',
      'push_notifications': 'Thông báo đẩy',
      'notifications_desc': 'Bật nhận tin nhắn & hóa đơn thanh toán',
      'language': 'Ngôn ngữ',
      'lang_active': 'Đang chọn: ',
      'lang_vi': 'Tiếng Việt',
      'lang_en': 'English',
      'data_section': 'DỌN DẸP DỮ LIỆU',
      'clear_search': 'Xóa lịch sử tìm kiếm',
      'clear_search_desc': 'Xóa danh sách từ khóa tìm kiếm gần đây',
      'clear_cache': 'Dọn dẹp bộ nhớ đệm',
      'clear_cache_desc': 'Giải phóng dữ liệu đệm',
      'account_section': 'TÀI KHOẢN',
      'change_password': 'Thay đổi mật khẩu',
      'change_password_desc': 'Cập nhật mật khẩu đăng nhập của bạn',
      'deactivate_account': 'Vô hiệu hóa tài khoản',
      'deactivate_account_desc': 'Yêu cầu tạm khóa tài khoản của bạn',
      'cancel': 'Hủy',
      'clear': 'Xóa sạch',
      'confirm': 'Đồng ý',
      'clear_search_confirm_title': 'Xóa lịch sử tìm kiếm?',
      'clear_search_confirm_desc': 'Bạn có chắc chắn muốn xóa toàn bộ lịch sử tìm kiếm gần đây không? Hành động này không thể phục hồi.',
      'clear_search_success': 'Đã xóa lịch sử tìm kiếm thành công',
      'clear_cache_confirm_title': 'Dọn dẹp bộ nhớ đệm?',
      'clear_cache_confirm_desc': 'Hành động này sẽ xóa các tệp hình ảnh và dữ liệu tạm thời đã lưu để giải phóng không gian bộ nhớ. Các tệp tin gốc không bị ảnh hưởng.',
      'clear_cache_success': 'Đã dọn dẹp bộ nhớ đệm ứng dụng thành công',
      'deactivate_confirm_title': 'CẢNH BÁO: Vô hiệu hóa tài khoản?',
      'deactivate_confirm_desc': 'Tài khoản của bạn sẽ bị khóa tạm thời. Bạn không thể tìm kiếm, liên hệ hoặc đăng tin phòng trọ. Để kích hoạt lại hoặc xóa vĩnh viễn dữ liệu, bạn cần liên hệ bộ phận hỗ trợ Swings House.',
      'deactivate_confirm_btn': 'Đồng ý vô hiệu hóa',
      'deactivate_success': 'Tài khoản của bạn đã được vô hiệu hóa tạm thời.',
      'lang_changed_snack': 'Đã thay đổi ngôn ngữ sang Tiếng Việt',
      'dialog_clean': 'Dọn dẹp',
    },
    'en': {
      'settings_title': 'System Settings',
      'interface_section': 'INTERFACE & CONFIGURATION',
      'app_theme': 'App Theme',
      'theme_mode_active': 'Applying: ',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'theme_system': 'System',
      'push_notifications': 'Push Notifications',
      'notifications_desc': 'Enable messages & payment invoices',
      'language': 'Language',
      'lang_active': 'Selected: ',
      'lang_vi': 'Tiếng Việt',
      'lang_en': 'English',
      'data_section': 'DATA CLEANING',
      'clear_search': 'Clear Search History',
      'clear_search_desc': 'Clear recent search keywords',
      'clear_cache': 'Clear App Cache',
      'clear_cache_desc': 'Free up cache data',
      'account_section': 'ACCOUNT',
      'change_password': 'Change Password',
      'change_password_desc': 'Update your login password',
      'deactivate_account': 'Deactivate Account',
      'deactivate_account_desc': 'Request to temporarily lock account',
      'cancel': 'Cancel',
      'clear': 'Clear',
      'confirm': 'Agree',
      'clear_search_confirm_title': 'Clear search history?',
      'clear_search_confirm_desc': 'Are you sure you want to clear all recent search history? This action cannot be undone.',
      'clear_search_success': 'Search history cleared successfully',
      'clear_cache_confirm_title': 'Clear app cache?',
      'clear_cache_confirm_desc': 'This action will clear cached images and temporary files to free up storage space. Original files are not affected.',
      'clear_cache_success': 'App cache cleared successfully',
      'deactivate_confirm_title': 'WARNING: Deactivate Account?',
      'deactivate_confirm_desc': 'Your account will be temporarily locked. You will not be able to search, contact, or post room listings. To reactivate or permanently delete data, please contact Swings House support.',
      'deactivate_confirm_btn': 'Agree to Deactivate',
      'deactivate_success': 'Your account has been temporarily deactivated.',
      'lang_changed_snack': 'Language changed to English',
      'dialog_clean': 'Clean',
    }
  };

  /// Translate a given key to the currently active language.
  static String tr(String key) {
    final lang = languageNotifier.value;
    return _localizedValues[lang]?[key] ?? key;
  }
}

/// Extension on [String] to make translation clean.
extension TranslationExtension on String {
  String get tr => AppLocalizations.tr(this);
}
