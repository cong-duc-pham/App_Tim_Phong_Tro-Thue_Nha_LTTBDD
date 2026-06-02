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
    return Review(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      listingId: json['listingId']?.toString() ?? json['ListingId']?.toString() ?? '',
      listingTitle: json['listingTitle'] ?? json['ListingTitle'] ?? '',
      listingAddress: json['listingAddress'] ?? json['ListingAddress'] ?? '',
      listingPrice: (json['listingPrice'] ?? json['ListingPrice'] ?? 0.0) is int
          ? (json['listingPrice'] ?? json['ListingPrice'] ?? 0).toDouble()
          : (json['listingPrice'] ?? json['ListingPrice'] ?? 0.0).toDouble(),
      listingImage: json['listingImage'] ?? json['ListingImage'],
      rating: (json['rating'] ?? json['Rating'] ?? 0.0) is int
          ? (json['rating'] ?? json['Rating'] ?? 0).toDouble()
          : (json['rating'] ?? json['Rating'] ?? 0.0).toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['CreatedAt'] != null
              ? DateTime.parse(json['CreatedAt'])
              : DateTime.now()),
      content: json['content'] ?? json['Content'] ?? '',
      replyContent: json['replyContent'] ?? json['ReplyContent'],
      repliedAt: json['repliedAt'] != null
          ? DateTime.parse(json['repliedAt'])
          : (json['RepliedAt'] != null
              ? DateTime.parse(json['RepliedAt'])
              : null),
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
