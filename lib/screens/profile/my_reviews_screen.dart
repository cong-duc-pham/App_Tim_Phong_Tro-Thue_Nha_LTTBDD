import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/review.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  // Danh sách đánh giá mẫu ban đầu của người dùng
  List<Review> _reviews = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  // Giả lập tải danh sách đánh giá từ API/Database cục bộ
  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 600)); // Hiệu ứng loading nhẹ
    setState(() {
      _reviews = [
        Review(
          id: 1,
          listingId: '1',
          listingTitle: 'Phòng trọ cao cấp có gác lửng Quận 10',
          listingAddress: '312 Tô Hiến Thành, Quận 10, TP.HCM',
          listingPrice: 4500000,
          rating: 5.0,
          createdAt: DateTime(2026, 5, 20),
          content: 'Phòng trọ sạch sẽ, rộng rãi, chủ nhà cực kỳ thân thiện và hỗ trợ nhiệt tình. Có chỗ để xe an toàn và giờ giấc tự do.',
          replyContent: 'Cảm ơn bạn đã lựa chọn phòng trọ của mình nhé! Chúc bạn có thời gian học tập và sinh sống thật vui vẻ tại đây.',
          repliedAt: DateTime(2026, 5, 21),
        ),
        Review(
          id: 2,
          listingId: '2',
          listingTitle: 'Phòng trọ giá sinh viên gần ĐH Bách Khoa',
          listingAddress: '82 Lý Thường Kiệt, Quận 10, TP.HCM',
          listingPrice: 2800000,
          rating: 4.0,
          createdAt: DateTime(2026, 5, 10),
          content: 'Giá cả hợp lý cho sinh viên, gần trường học nên đi bộ rất tiện. Phòng hơi nóng vào buổi trưa nhưng có điều hòa hỗ trợ.',
          replyContent: 'Chào bạn, cảm ơn phản hồi của bạn. Mình sẽ nghiên cứu nâng cấp thêm lớp chống nóng mái tôn để các bạn ở dễ chịu hơn.',
          repliedAt: DateTime(2026, 5, 11),
        ),
      ];
      _isLoading = false;
    });
  }

  // Định dạng hiển thị giá tiền VND
  String _formatPrice(double price) {
    if (price >= 1000000) {
      final m = price / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)} triệu/tháng';
    }
    return '${price.toInt()}đ/tháng';
  }

  // Định dạng ngày tháng hiển thị dd/MM/yyyy
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day/$month/$year';
  }

  // Xóa một đánh giá cụ thể sau khi người dùng xác nhận
  void _deleteReview(int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: const Text('Xóa đánh giá này?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Đánh giá này sẽ bị gỡ vĩnh viễn khỏi phòng trọ. Bạn có chắc chắn muốn thực hiện hành động này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _reviews.removeWhere((item) => item.id == id);
              });
              // Hiển thị phản hồi trực quan bằng SnackBar
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã gỡ bài đánh giá thành công!'),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Đồng ý'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reviews.isEmpty
                    ? _buildEmptyState()
                    : _buildReviewsList(),
          ),
        ],
      ),
    );
  }

  // Header bo góc tròn, màu sắc đồng bộ với giao diện chung của ứng dụng
  Widget _buildHeader() {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Đánh giá của tôi',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Container(
              height: 20,
              decoration: const BoxDecoration(
                color: AppColors.bgPage,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Danh sách các thẻ bài đánh giá
  Widget _buildReviewsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        final review = _reviews[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Phần thông tin phòng trọ được đánh giá
              InkWell(
                onTap: () {
                  // Chuyển hướng người dùng về Trang chủ để lọc đúng phòng trọ này
                  context.go('/home?q=${Uri.encodeComponent(review.listingTitle)}');
                },
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppConstants.radiusLg),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Thumbnail giả lập (Sử dụng Container trang trí bo góc)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.home_work_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.listingTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              review.listingAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatPrice(review.listingPrice),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.borderLight),
              
              // 2. Nội dung sao đánh giá, ngày tháng và văn bản đánh giá
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Star Rating Row
                        Row(
                          children: List.generate(5, (starIndex) {
                            final filled = starIndex < review.rating;
                            return Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: filled ? Colors.amber : Colors.grey[300],
                            );
                          }),
                        ),
                        Text(
                          _formatDate(review.createdAt),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      review.content,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),

                    // 3. Khung hiển thị câu trả lời của chủ nhà (nếu có)
                    if (review.replyContent != null) ...[
                      Container(
                        margin: const EdgeInsets.only(top: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.maps_ugc_rounded,
                                  color: AppColors.primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Chủ nhà phản hồi',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const Spacer(),
                                if (review.repliedAt != null)
                                  Text(
                                    _formatDate(review.repliedAt!),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              review.replyContent!,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const Divider(height: 1, color: AppColors.borderLight),
              
              // 4. Các nút hành động dưới chân thẻ bài đánh giá
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Nút xóa đánh giá riêng tư có Touch Target rộng rãi (48px)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _deleteReview(review.id),
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(AppConstants.radiusLg),
                      ),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        child: const Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 16,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Gỡ đánh giá',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Trạng thái trống (Empty State) hiển thị khi không còn bài viết đánh giá nào
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 64),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.rate_review_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Không có đánh giá',
            style: AppTextStyles.h3,
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn chưa gửi bất kỳ lượt đánh giá chất lượng phòng trọ nào.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 32),
          // Nút quay lại trang chủ tìm phòng
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
            ),
            child: const Text(
              'Khám phá phòng trọ ngay',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
