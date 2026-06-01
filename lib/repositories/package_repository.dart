import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/payment.dart';
import '../models/post_package.dart';
import '../services/api_service.dart';

class PackageRepository {
  PackageRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<PostPackage>> getPackages() async {
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/packages',
      );
      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! List) return const [];

      final packages = data
          .whereType<Map>()
          .map((item) => PostPackage.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      packages.sort((a, b) => a.price.compareTo(b.price));
      return packages;
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<Invoice> purchasePackage({
    required int listingId,
    required int packageId,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/packages/purchase',
          data: {
            'listingId': listingId,
            'packageId': packageId,
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final data =
          (response.data ?? {})['data'] ?? (response.data ?? {})['Data'];
      if (data is! Map) {
        throw Exception('Backend không trả về hóa đơn.');
      }

      return Invoice.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<void> simulateMomoPayment(String invoiceCode) async {
    try {
      await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/packages/simulate-momo-payment',
          data: {'invoiceCode': invoiceCode},
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
      throw Exception('Bạn cần đăng nhập để mua gói VIP.');
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
      if (accessToken is! String || accessToken.isEmpty) return null;

      await prefs.setString(AppConstants.keyUserToken, accessToken);
      if (newRefreshToken is String && newRefreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', newRefreshToken);
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
