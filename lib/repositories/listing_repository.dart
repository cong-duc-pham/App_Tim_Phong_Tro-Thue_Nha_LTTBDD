import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/listing.dart';
import '../models/amenity.dart';
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

  Future<Listing?> getListing(int listingId) async {
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/listings/$listingId',
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        return null;
      }

      return Listing.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  // Lấy chi tiết một tin đăng theo ID — public, không cần auth
  Future<Listing> getListingById(int id) async {
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/listings/$id',
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Không tìm thấy tin đăng.');
      }

      return Listing.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<List<Listing>> getMyListings() async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.get<Map<String, dynamic>>(
          '/listings/my-listings',
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) return const [];

      return data
          .whereType<Map>()
          .map((item) => Listing.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  // Tăng lượt xem — fire-and-forget, không throw nếu lỗi
  Future<void> incrementView(int id) async {
    try {
      await _apiService.dio.post<void>('/listings/$id/view');
    } catch (_) {
      // Bỏ qua lỗi — không ảnh hưởng trải nghiệm người dùng
    }
  }
  Future<Listing> createListing(Map<String, dynamic> payload) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/listings',
          data: payload,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
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
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.put<Map<String, dynamic>>(
          '/listings/$listingId',
          data: payload,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
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
      final fileName = filePath.split(RegExp(r'[\\/]')).last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'uploadType': isCover ? 'cover' : 'gallery',
      });

      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/storage/listings/$listingId/images',
          data: formData,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
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

  Future<String> uploadListingVideo({
    required int listingId,
    required String filePath,
  }) async {
    try {
      final fileName = filePath.split(RegExp(r'[\\/]')).last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/storage/listings/$listingId/videos',
          data: formData,
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Backend khong tra ve URL video.');
      }

      final url = data['url'] ?? data['Url'];
      if (url is! String || url.isEmpty) {
        throw Exception('URL video khong hop le.');
      }

      return url;
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
      if (userId != null) await prefs.setString(AppConstants.keyUserId, userId.toString());
      if (fullName != null) await prefs.setString('user_full_name', fullName.toString());
      if (role != null) await prefs.setString(AppConstants.keyUserRole, role.toString());

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

  Future<List<Amenity>> getAmenities() async {
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/categories/amenities',
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) {
        return const [];
      }

      return data
          .whereType<Map>()
          .map((item) => Amenity.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }
}
