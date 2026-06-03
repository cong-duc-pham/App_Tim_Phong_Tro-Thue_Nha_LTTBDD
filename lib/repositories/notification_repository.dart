import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/app_notification.dart';
import '../services/api_service.dart';

class NotificationRepository {
  NotificationRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<AppNotification>> getNotifications() async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.get<Map<String, dynamic>>(
          '/notifications',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((item) =>
              AppNotification.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.get<Map<String, dynamic>>(
          '/notifications/unread-count',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final body = response.data ?? {};
      final value = body['unreadCount'] ?? body['UnreadCount'];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.put<Map<String, dynamic>>(
          '/notifications/$notificationId/read',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<Response<T>> _authorizedRequest<T>(
    Future<Response<T>> Function(String accessToken) request,
  ) async {
    final firstToken = await _getBackendAccessToken();

    try {
      return await request(firstToken);
    } on DioException catch (e) {
      if (e.response?.statusCode != 401) rethrow;

      final refreshedToken = await _refreshBackendAccessToken();
      if (refreshedToken == null) {
        throw Exception('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.');
      }

      return request(refreshedToken);
    }
  }

  Future<String> _getBackendAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(AppConstants.keyUserToken);
    if (savedToken != null && savedToken.isNotEmpty) {
      return savedToken;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Bạn cần đăng nhập để xem thông báo.');
    }

    final firebaseToken = await user.getIdToken(true);
    if (firebaseToken == null || firebaseToken.isEmpty) {
      throw Exception('Không lấy được Firebase token.');
    }

    late final Response<Map<String, dynamic>> response;
    try {
      response = await _apiService.dio.post<Map<String, dynamic>>(
        '/auth/firebase-login',
        data: {'firebaseToken': firebaseToken},
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }

    final body = response.data ?? {};
    final data = body['data'] ?? body['Data'];
    if (data is! Map) {
      throw Exception('Backend không trả về access token.');
    }

    final token = data['accessToken'] ?? data['AccessToken'];
    if (token is! String || token.isEmpty) {
      throw Exception('Access token không hợp lệ.');
    }

    await prefs.setString(AppConstants.keyUserToken, token);
    return token;
  }

  Future<String?> _refreshBackendAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null || refreshToken.isEmpty) {
      await prefs.remove(AppConstants.keyUserToken);
      return null;
    }

    try {
      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/auth/refresh-token',
        data: {'refreshToken': refreshToken},
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) return null;

      final accessToken = data['accessToken'] ?? data['AccessToken'];
      final newRefreshToken = data['refreshToken'] ?? data['RefreshToken'];
      final userId = data['userId'] ?? data['UserId'];
      final fullName = data['fullName'] ?? data['FullName'];
      final role = data['role'] ?? data['Role'];

      if (accessToken is! String || accessToken.isEmpty) return null;

      await prefs.setString(AppConstants.keyUserToken, accessToken);
      if (newRefreshToken is String && newRefreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', newRefreshToken);
      }
      if (userId != null) {
        await prefs.setString(AppConstants.keyUserId, userId.toString());
      }
      if (fullName != null) {
        await prefs.setString('user_full_name', fullName.toString());
      }
      if (role != null) {
        await prefs.setString(AppConstants.keyUserRole, role.toString());
      }

      return accessToken;
    } on DioException {
      await prefs.remove(AppConstants.keyUserToken);
      await prefs.remove('refresh_token');
      return null;
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
    return e.message ?? 'Không kết nối được backend.';
  }
}
