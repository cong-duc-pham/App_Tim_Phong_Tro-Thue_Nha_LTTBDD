// lib/repositories/review_repository.dart

import 'package:dio/dio.dart';
import 'base_repository.dart';
import '../models/review.dart';

class ReviewRepository extends BaseRepository {
  ReviewRepository({super.apiService});

  /// Lấy danh sách đánh giá của một phòng trọ.
  Future<List<Review>> getListingReviews(int listingId) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        '/listings/$listingId/reviews',
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! List) {
        return const [];
      }

      return data
          .whereType<Map>()
          .map((item) => Review.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Tạo đánh giá mới cho một phòng trọ.
  Future<Review> createReview({
    required int listingId,
    required double rating,
    required String content,
  }) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.post<Map<String, dynamic>>(
        '/listings/$listingId/reviews',
        data: {
          'rating': rating,
          'content': content,
        },
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Không thể tạo đánh giá.');
      }

      return Review.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Phản hồi đánh giá (dành cho chủ trọ).
  Future<void> replyReview({
    required int reviewId,
    required String replyContent,
  }) async {
    try {
      final options = await getOptionsWithToken();
      await dio.post<Map<String, dynamic>>(
        '/reviews/$reviewId/reply',
        data: {
          'replyContent': replyContent,
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
