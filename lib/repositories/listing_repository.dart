import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/listing.dart';
import '../services/api_service.dart';

class ListingRepository {
  ListingRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  Future<List<Listing>> getListings({
    int page = 1,
    int pageSize = 20,
    String sortBy = 'newest',
    bool? isFeatured,
    String? keyword,
  }) async {
    final response = await _apiService.dio.get<Map<String, dynamic>>(
      '/listings',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'sortBy': sortBy,
        if (isFeatured != null) 'isFeatured': isFeatured,
        if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      },
    );

    final body = response.data ?? {};
    final data = body['data'] ?? body['Data'];
    if (data is! List) {
      return const [];
    }

    return data
        .whereType<Map>()
        .map((item) => Listing.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Listing> createListing(Map<String, dynamic> payload) async {
    try {
      final accessToken = await _getBackendAccessToken();
      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/listings',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Backend không trả về thông tin tin đăng.');
      }

      return Listing.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<Listing> updateListing(int listingId, Map<String, dynamic> payload) async {
    try {
      final accessToken = await _getBackendAccessToken();
      final response = await _apiService.dio.put<Map<String, dynamic>>(
        '/listings/$listingId',
        data: payload,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Backend không trả về thông tin tin đăng.');
      }

      return Listing.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<String> uploadListingImage({
    required int listingId,
    required String filePath,
    required bool isCover,
  }) async {
    try {
      final accessToken = await _getBackendAccessToken();
      final fileName = filePath.split(RegExp(r'[\\/]')).last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'uploadType': isCover ? 'cover' : 'gallery',
      });

      final response = await _apiService.dio.post<Map<String, dynamic>>(
        '/storage/listings/$listingId/images',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Backend không trả về URL ảnh.');
      }

      final url = data['url'] ?? data['Url'];
      if (url is! String || url.isEmpty) {
        throw Exception('URL ảnh không hợp lệ.');
      }

      return url;
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
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
      throw Exception('Bạn cần đăng nhập trước khi đăng tin.');
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

    return token;
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
