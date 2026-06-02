// lib/repositories/user_repository.dart

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/app_constants.dart';
import 'base_repository.dart';
import '../models/user.dart';

class UserRepository extends BaseRepository {
  UserRepository({super.apiService});

  /// Lấy thông tin cá nhân của người dùng hiện tại từ backend.
  Future<User?> getCurrentUserProfile() async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.get<Map<String, dynamic>>(
        '/auth/me',
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        return null;
      }

      return User.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Cập nhật thông tin cá nhân.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
  }) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.put<Map<String, dynamic>>(
        '/auth/profile',
        data: {
          'fullName': fullName,
          'phone': phone,
        },
        options: options,
      );

      final body = response.data ?? {};
      final success = body['success'] ?? body['Success'] ?? false;
      if (!success) {
        throw Exception(body['message'] ?? body['Message'] ?? 'Cập nhật thất bại.');
      }

      // Lưu lại thông tin vào SharedPreferences để đồng bộ local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_full_name', fullName);
      await prefs.setString('user_phone', phone);
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Cập nhật token FCM cho thông báo đẩy.
  Future<void> updateFcmToken(String fcmToken) async {
    try {
      final options = await getOptionsWithToken();
      await dio.post<Map<String, dynamic>>(
        '/auth/update-fcm-token',
        data: {
          'fcmToken': fcmToken,
        },
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  String _readBackendMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final message = data['message'] ?? data['Message'];
      if (message != null) return message.toString();
    }
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }
    return e.message ?? 'Lỗi kết nối máy chủ.';
  }
}
