import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../services/api_service.dart';

class ConversationRepository {
  ConversationRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<Conversation>> getConversations() async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.get<Map<String, dynamic>>(
          '/conversations',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<Conversation> createConversation({
    required int listingId,
    required int landlordId,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/conversations',
          data: {
            'listingId': listingId,
            'landlordId': landlordId,
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! Map) {
        throw Exception('Backend khÃ´ng tráº£ vá» há»™i thoáº¡i.');
      }

      return Conversation.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<List<Message>> getMessages(int conversationId, {int page = 1}) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.get<Map<String, dynamic>>(
          '/conversations/$conversationId/messages',
          queryParameters: {'page': page},
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((item) => Message.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<Message> sendMessage({
    required int conversationId,
    required String content,
    String msgType = 'text',
    String? fileUrl,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/conversations/$conversationId/messages',
          data: {
            'convId': conversationId,
            'content': content,
            'msgType': msgType,
            'fileUrl': fileUrl,
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! Map) {
        throw Exception('Backend không trả về tin nhắn.');
      }

      return Message.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<void> markAsRead(int conversationId) async {
    try {
      await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.put<Map<String, dynamic>>(
          '/conversations/$conversationId/read',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<Map<String, dynamic>> confirmRental(int conversationId) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/rentals/confirm-from-chat/$conversationId',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );
      return Map<String, dynamic>.from(response.data ?? {});
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<int?> getCurrentBackendUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString(AppConstants.keyUserId) ?? '');
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
      throw Exception('Bạn cần đăng nhập để sử dụng tin nhắn.');
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
