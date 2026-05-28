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
}
