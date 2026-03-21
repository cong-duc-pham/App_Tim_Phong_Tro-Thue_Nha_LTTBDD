// lib/core/utils/validators.dart
// Thay thế form_builder_validators - dùng trực tiếp trong TextFormField

class Validators {
  Validators._();

  // Bắt buộc nhập
  static String? required(String? value, {String? message}) {
    if (value == null || value.trim().isEmpty) {
      return message ?? 'Vui lòng không để trống';
    }
    return null;
  }

  // Validate email
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập email';
    final regex = RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Email không hợp lệ';
    return null;
  }

  // Validate số điện thoại Việt Nam
  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
    final regex = RegExp(r'^(0|\+84)(3|5|7|8|9)\d{8}$');
    if (!regex.hasMatch(value.trim())) return 'Số điện thoại không hợp lệ';
    return null;
  }

  // Validate mật khẩu (tối thiểu 6 ký tự)
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (value.length < 6) return 'Mật khẩu tối thiểu 6 ký tự';
    return null;
  }

  // Validate xác nhận mật khẩu
  static String? Function(String?) confirmPassword(String? password) {
    return (String? value) {
      if (value == null || value.isEmpty) return 'Vui lòng xác nhận mật khẩu';
      if (value != password) return 'Mật khẩu không khớp';
      return null;
    };
  }

  // Validate giá tiền (VNĐ)
  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập giá thuê';
    final number = num.tryParse(value.replaceAll('.', '').replaceAll(',', ''));
    if (number == null) return 'Giá tiền không hợp lệ';
    if (number <= 0) return 'Giá tiền phải lớn hơn 0';
    return null;
  }

  // Validate diện tích (m²)
  static String? area(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập diện tích';
    final number = num.tryParse(value);
    if (number == null) return 'Diện tích không hợp lệ';
    if (number <= 0) return 'Diện tích phải lớn hơn 0';
    return null;
  }

  // Validate OTP (6 chữ số)
  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'Vui lòng nhập mã OTP';
    if (value.trim().length != 6) return 'OTP gồm 6 chữ số';
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) return 'OTP chỉ gồm chữ số';
    return null;
  }

  // Kết hợp nhiều validator (chạy theo thứ tự, dừng khi có lỗi)
  static String? Function(String?) compose(
      List<String? Function(String?)> validators) {
    return (String? value) {
      for (final v in validators) {
        final error = v(value);
        if (error != null) return error;
      }
      return null;
    };
  }
}