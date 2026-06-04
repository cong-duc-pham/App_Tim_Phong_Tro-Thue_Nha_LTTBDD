// lib/repositories/review_repository.dart

import 'package:dio/dio.dart';
import 'base_repository.dart';
import '../models/review.dart';

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
  final int likeCount;
  final bool isLiked;

  const ReviewItem({
    required this.reviewId,
    required this.reviewerName,
    this.reviewerAvatar,
    required this.rating,
    required this.content,
    this.replyContent,
    required this.createdAt,
    this.repliedAt,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory ReviewItem.fromJson(Map<String, dynamic> json) {
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    final createdRaw = json['createdAt'] ?? json['CreatedAt'];
    final repliedRaw = json['repliedAt'] ?? json['RepliedAt'];
    final ratingRaw = json['rating'] ?? json['Rating'];
    final likeCountRaw = json['likeCount'] ?? json['LikeCount'];
    final isLikedRaw = json['isLiked'] ?? json['IsLiked'];

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
      likeCount: likeCountRaw is num
          ? likeCountRaw.toInt()
          : int.tryParse(likeCountRaw?.toString() ?? '') ?? 0,
      isLiked: isLikedRaw is bool
          ? isLikedRaw
          : isLikedRaw?.toString().toLowerCase() == 'true',
    );
  }
}

class ReviewRepository extends BaseRepository {
  ReviewRepository({super.apiService});

  Future<List<Review>> getMyReviews() async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.get<Map<String, dynamic>>(
        '/reviews/me',
        options: options,
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

  Future<void> deleteReview(int reviewId) async {
    try {
      final options = await getOptionsWithToken();
      await dio.delete<Map<String, dynamic>>(
        '/reviews/$reviewId',
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  /// Lấy danh sách đánh giá của một phòng trọ dạng đơn giản.
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

  // lấy reviews của một tin đăng kèm thống kê sao, không cần auth (dành cho chi tiết tin)
  Future<({List<ReviewItem> reviews, double averageRating, int count})>
      getReviews(int listingId) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.get<Map<String, dynamic>>(
        '/listings/$listingId/reviews',
        options: options,
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

  /// Tạo đánh giá mới cho một phòng trọ.
  Future<ReviewItem> createReview({
    required int listingId,
    required int rating,
    required String comment,
  }) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.post<Map<String, dynamic>>(
        '/listings/$listingId/reviews',
        data: {
          'rating': rating,
          'comment': comment,
        },
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Không thể tạo đánh giá.');
      }

      return ReviewItem.fromJson(Map<String, dynamic>.from(data));
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
          'reply': replyContent,
        },
        options: options,
      );
    } on DioException catch (e) {
      throw Exception(_readBackendMessage(e));
    }
  }

  Future<ReviewItem> toggleLike(int reviewId) async {
    try {
      final options = await getOptionsWithToken();
      final response = await dio.post<Map<String, dynamic>>(
        '/reviews/$reviewId/like',
        options: options,
      );

      final body = response.data ?? {};
      final data = body['data'] ?? body['Data'];
      if (data is! Map) {
        throw Exception('Không thể cập nhật lượt thích.');
      }

      return ReviewItem.fromJson(Map<String, dynamic>.from(data));
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
