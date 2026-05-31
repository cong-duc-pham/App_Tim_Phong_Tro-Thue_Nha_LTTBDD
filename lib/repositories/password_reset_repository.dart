import 'package:dio/dio.dart';

import '../services/api_service.dart';

class PasswordResetRepository {
  PasswordResetRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<void> requestOtp(String email) async {
    try {
      await _apiService.dio.post(
        '/auth/forgot-password',
        data: {'email': email.trim()},
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<void> resetPassword({
    required String email,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      await _apiService.dio.post(
        '/auth/reset-password',
        data: {
          'email': email.trim(),
          'otpCode': otpCode.trim(),
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  String _readBackendMessage(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Kết nối máy chủ quá lâu. Hãy kiểm tra backend đang chạy ở cổng 61795.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Không kết nối được backend. Hãy chạy Backend_API trước khi gửi OTP.';
    }

    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['Message'];
      if (message != null) return message.toString();
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return e.message ?? 'Không kết nối được backend.';
  }
}
