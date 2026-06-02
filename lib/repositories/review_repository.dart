// lib/repositories/review_repository.dart

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../services/api_service.dart';

// model dùng riêng cho màn hình detail, không dùng chung với Review model của my_reviews
class ReviewItem {
  final int reviewId;
  final String reviewerName;
  final String? reviewerAvatar;
  final double rating;
  final String content;
  final String? replyContent; // phản hồi của chủ trọ nếu có
  final DateTime createdAt;
  final DateTime? repliedAt;

  const ReviewItem({
    required this.reviewId,
    required this.reviewerName,
    this.reviewerAvatar,
    required this.rating,
    required this.content,
    this.replyContent,
    required this.createdAt,
    this.repliedAt,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    final createdRaw = json['createdAt'] ?? json['CreatedAt'];
    final repliedRaw = json['repliedAt'] ?? json['RepliedAt'];
    final ratingRaw = json['rating'] ?? json['Rating'];

    return ReviewItem(
      reviewId: (json['reviewId'] ?? json['ReviewId'] ?? 0) as int,
      reviewerName: read<String>('reviewerName', 'ReviewerName') ?? 'Ẩn danh',
      reviewerAvatar: read<String>('reviewerAvatar', 'ReviewerAvatar'),
      rating: ratingRaw is num ? ratingRaw.toDouble() : 0.0,
      content: read<String>('content', 'Content') ??
          read<String>('comment', 'Comment') ??
          '',
      replyContent: read<String>('replyContent', 'ReplyContent') ??
          read<String>('landlordReply', 'LandlordReply'),
      createdAt: createdRaw != null
          ? DateTime.tryParse(createdRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      repliedAt:
          repliedRaw != null ? DateTime.tryParse(repliedRaw.toString()) : null,
    );
  }
}

class ReviewRepository {
  ReviewRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  final ApiService _apiService;

  // lấy reviews của một tin đăng, không cần auth
  Future<({List<ReviewItem> reviews, double averageRating, int count})>
      getReviews(int listingId) async {
    try {
      final response = await _apiService.dio.get<Map<String, dynamic>>(
        '/listings/$listingId/reviews',
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      final avgRaw = body['averageRating'] ?? body['AverageRating'] ?? 0;
      final countRaw = body['count'] ?? body['Count'] ?? 0;

      final reviews = data is List
          ? data
              .whereType<Map>()
              .map((e) => ReviewItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <ReviewItem>[];

      return (
        reviews: reviews,
        averageRating: avgRaw is num ? avgRaw.toDouble() : 0.0,
        count: countRaw is num ? countRaw.toInt() : 0,
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<ReviewItem> createReview({
    required int listingId,
    required int rating,
    required String comment,
  }) async {
    try {
      final response = await _authorizedRequest<Map<String, dynamic>>(
        (accessToken) => _apiService.dio.post<Map<String, dynamic>>(
          '/listings/$listingId/reviews',
          data: {
            'rating': rating,
            'comment': comment,
          },
          options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        ),
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Backend không trả về đánh giá vừa tạo.');
      }

      return ReviewItem.fromJson(Map<String, dynamic>.from(data));
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
      throw Exception('Bạn cần đăng nhập để gửi đánh giá.');
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
    if (data is String && data.trim().isNotEmpty) return data;
    return e.message ?? 'Không kết nối được backend.';
  }
}
