import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/viewing_appointment.dart';
import '../services/api_service.dart';

class ViewingAppointmentSlot {
  final DateTime scheduledAt;
  final String label;
  final bool isAvailable;

  const ViewingAppointmentSlot({
    required this.scheduledAt,
    required this.label,
    required this.isAvailable,
  });

  factory ViewingAppointmentSlot.fromJson(Map<String, dynamic> json) {
    final scheduledAtRaw = json['scheduledAt'] ?? json['ScheduledAt'];
    return ViewingAppointmentSlot(
      scheduledAt:
          DateTime.tryParse(scheduledAtRaw?.toString() ?? '')?.toLocal() ??
              DateTime.now(),
      label: (json['label'] ?? json['Label'] ?? '').toString(),
      isAvailable: json['isAvailable'] == true ||
          json['IsAvailable'] == true ||
          json['isAvailable']?.toString().toLowerCase() == 'true' ||
          json['IsAvailable']?.toString().toLowerCase() == 'true',
    );
  }
}

class ViewingAppointmentRepository {
  ViewingAppointmentRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<ViewingAppointmentSlot>> getAvailableSlots({
    required int listingId,
    required DateTime date,
  }) async {
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/viewing-appointments/listings/$listingId/available-slots',
        queryParameters: {
          'date':
              '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
          'timezoneOffsetMinutes': date.timeZoneOffset.inMinutes,
        },
      );

      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((item) =>
              ViewingAppointmentSlot.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<List<ViewingAppointment>> getMyAppointments({
    String? role,
    String? status,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.get<Map<String, dynamic>>(
          '/viewing-appointments',
          queryParameters: {
            if (role != null && role.isNotEmpty) 'role': role,
            if (status != null && status.isNotEmpty) 'status': status,
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((item) =>
              ViewingAppointment.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<ViewingAppointment> createAppointment({
    required int listingId,
    required DateTime scheduledAt,
    String? note,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/viewing-appointments',
          data: {
            'listingId': listingId,
            'scheduledAt': scheduledAt.toUtc().toIso8601String(),
            'timezoneOffsetMinutes': scheduledAt.timeZoneOffset.inMinutes,
            if (note != null && note.trim().isNotEmpty)
              'tenantNote': note.trim(),
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      return _readAppointment(response.data);
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<ViewingAppointment> confirm(int appointmentId, {String? note}) {
    return _patchStatus(appointmentId, 'confirm', note: note);
  }

  Future<ViewingAppointment> decline(int appointmentId, {String? note}) {
    return _patchStatus(appointmentId, 'decline', note: note);
  }

  Future<ViewingAppointment> cancel(int appointmentId, {String? note}) {
    return _patchStatus(appointmentId, 'cancel', note: note);
  }

  Future<ViewingAppointment> _patchStatus(
    int appointmentId,
    String action, {
    String? note,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.patch<Map<String, dynamic>>(
          '/viewing-appointments/$appointmentId/$action',
          data: {
            if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      return _readAppointment(response.data);
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  ViewingAppointment _readAppointment(Map<String, dynamic>? body) {
    final data = (body ?? {})['data'] ?? (body ?? {})['Data'];
    if (data is! Map) {
      throw Exception('Backend không trả về lịch hẹn hợp lệ.');
    }

    return ViewingAppointment.fromJson(Map<String, dynamic>.from(data));
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
      throw Exception('Bạn cần đăng nhập để đặt lịch xem phòng.');
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
