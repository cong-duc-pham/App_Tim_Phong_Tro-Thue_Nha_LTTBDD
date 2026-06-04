// lib/models/review.dart

class Review {
  final int id;
  // ID phòng trọ được đánh giá
  final String listingId;
  // Tiêu đề phòng trọ
  final String listingTitle;
  // Địa chỉ phòng trọ
  final String listingAddress;
  // Giá thuê phòng trọ
  final double listingPrice;
  // Ảnh đại diện phòng trọ
  final String? listingImage;
  // Số sao đánh giá (từ 1.0 đến 5.0)
  final double rating;
  // Ngày tạo đánh giá
  final DateTime createdAt;
  // Nội dung bài đánh giá
  final String content;
  // Nội dung phản hồi từ chủ nhà (nếu có)
  final String? replyContent;
  // Ngày chủ nhà phản hồi
  final DateTime? repliedAt;

  const Review({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.listingAddress,
    required this.listingPrice,
    this.listingImage,
    required this.rating,
    required this.createdAt,
    required this.content,
    this.replyContent,
    this.repliedAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    int integer(String camel, String pascal,
        [String? fallbackCamel, String? fallbackPascal]) {
      final value = json[camel] ??
          json[pascal] ??
          json[fallbackCamel] ??
          json[fallbackPascal];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double number(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    String text(String camel, String pascal, [String? fallback]) {
      final value = json[camel] ?? json[pascal] ?? json[fallback];
      return value?.toString() ?? '';
    }

    DateTime? date(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value == null ? null : DateTime.tryParse(value.toString());
    }

    return Review(
      id: integer('id', 'Id', 'reviewId', 'ReviewId'),
      listingId: text('listingId', 'ListingId'),
      listingTitle: text('listingTitle', 'ListingTitle'),
      listingAddress: text('listingAddress', 'ListingAddress'),
      listingPrice: number('listingPrice', 'ListingPrice'),
      listingImage: json['listingImage'] ?? json['ListingImage'],
      rating: number('rating', 'Rating'),
      createdAt: date('createdAt', 'CreatedAt') ?? DateTime.now(),
      content: text('content', 'Content', 'comment'),
      replyContent: json['replyContent'] ??
          json['ReplyContent'] ??
          json['landlordReply'] ??
          json['LandlordReply'],
      repliedAt: date('repliedAt', 'RepliedAt'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingAddress': listingAddress,
      'listingPrice': listingPrice,
      'listingImage': listingImage,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
      'content': content,
      'replyContent': replyContent,
      'repliedAt': repliedAt?.toIso8601String(),
    };
  }
}
