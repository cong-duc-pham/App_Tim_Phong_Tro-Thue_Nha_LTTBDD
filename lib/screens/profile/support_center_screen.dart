import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';

class _FAQItem {
  final String question;
  final String answer;
  final String category;

  const _FAQItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

class SupportCenterScreen extends StatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  State<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends State<SupportCenterScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const List<_FAQItem> _faqList = [
    // Category: Tìm kiếm & Thuê phòng
    _FAQItem(
      category: 'Tìm kiếm & Thuê phòng',
      question: 'Làm sao để tìm phòng trọ gần trường học/nơi làm việc?',
      answer: 'Bạn có thể nhập tên trường hoặc khu vực vào ô tìm kiếm ở trang chủ. Sử dụng bộ lọc nâng cao để chọn khoảng giá, diện tích và các tiện ích mong muốn.',
    ),
    _FAQItem(
      category: 'Tìm kiếm & Thuê phòng',
      question: 'Tôi muốn đặt cọc giữ chỗ thì có an toàn không?',
      answer: 'Để đảm bảo an toàn, bạn nên hẹn chủ nhà xem phòng thực tế trước khi đặt cọc. Nên yêu cầu giấy tờ biên nhận đặt cọc rõ ràng và không chuyển khoản trước cho người lạ.',
    ),
    _FAQItem(
      category: 'Tìm kiếm & Thuê phòng',
      question: 'Làm thế nào để lưu lại các phòng trọ tôi yêu thích?',
      answer: 'Bạn có thể nhấn vào biểu tượng trái tim (Favorite) ở góc các thẻ phòng trọ. Danh sách phòng đã lưu sẽ hiển thị trong trang Cá nhân -> Phòng đã lưu hoặc tab Yêu thích dưới thanh điều hướng.',
    ),

    // Category: Đăng tin & Chủ nhà
    _FAQItem(
      category: 'Đăng tin & Chủ nhà',
      question: 'Làm sao để đăng tin cho thuê phòng trọ?',
      answer: 'Bạn hãy chuyển đổi tài khoản sang vai trò "Chủ nhà" trong phần thông tin cá nhân. Sau đó nhấn nút "+" (Đăng tin) ở thanh điều hướng dưới cùng để điền thông tin phòng.',
    ),
    _FAQItem(
      category: 'Đăng tin & Chủ nhà',
      question: 'Tin đăng VIP khác gì so với tin đăng thường?',
      answer: 'Tin VIP sẽ được ghim ở đầu trang chủ, hiển thị nổi bật với nhãn màu xanh và được hệ thống ưu tiên tiếp cận gấp 5 lần so với tin đăng thông thường.',
    ),
    _FAQItem(
      category: 'Đăng tin & Chủ nhà',
      question: 'Tôi có thể đăng tối đa bao nhiêu ảnh cho một phòng trọ?',
      answer: 'Đối với gói tin miễn phí, bạn có thể tải lên tối đa 1 ảnh. Với các gói tin đăng VIP hoặc Featured, bạn có thể tải lên từ 10 đến không giới hạn số lượng ảnh chất lượng cao để thu hút người thuê.',
    ),

    // Category: Tài khoản & Bảo mật
    _FAQItem(
      category: 'Tài khoản & Bảo mật',
      question: 'Làm thế nào để xác thực tài khoản (Verified Badge)?',
      answer: 'Trong trang Cá nhân, nhấn vào mục "Xác thực tài khoản" và tải lên ảnh căn cước công dân hoặc giấy tờ xác minh cần thiết. Đội ngũ kiểm duyệt sẽ xử lý trong vòng 24 giờ.',
    ),
    _FAQItem(
      category: 'Tài khoản & Bảo mật',
      question: 'Tôi quên mật khẩu đăng nhập phải làm sao?',
      answer: 'Tại màn hình Đăng nhập, chọn "Quên mật khẩu", nhập email đăng ký của bạn. Hệ thống sẽ gửi một liên kết đặt lại mật khẩu về email đó.',
    ),
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_FAQItem> _getFilteredFAQs() {
    if (_searchQuery.trim().isEmpty) return _faqList;
    final query = _searchQuery.toLowerCase().trim();
    return _faqList.where((item) {
      return item.question.toLowerCase().contains(query) ||
          item.answer.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFAQs = _getFilteredFAQs();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBox(),
          Expanded(
            child: filteredFAQs.isEmpty
                ? _buildEmptyState()
                : _buildFAQContent(filteredFAQs),
          ),
        ],
      ),
    );
  }

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
                    'Trung tâm hỗ trợ',
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

  Widget _buildSearchBox() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextFormField(
          controller: _searchCtrl,
          onChanged: (val) {
            setState(() {
              _searchQuery = val;
            });
          },
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm câu hỏi thường gặp...',
            hintStyle: AppTextStyles.inputHint,
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQContent(List<_FAQItem> faqs) {
    if (_searchQuery.trim().isNotEmpty) {
      // Khi đang tìm kiếm, hiển thị danh sách phẳng trực quan
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: faqs.length,
        itemBuilder: (context, index) {
          return _buildFAQTile(faqs[index]);
        },
      );
    }

    // Khi không tìm kiếm, nhóm các câu hỏi theo danh mục
    final Map<String, List<_FAQItem>> groupedFAQs = {};
    for (var item in faqs) {
      groupedFAQs.putIfAbsent(item.category, () => []).add(item);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: groupedFAQs.entries.map((entry) {
        final categoryName = entry.key;
        final categoryItems = entry.value;

        IconData categoryIcon = Icons.help_center_rounded;
        if (categoryName.contains('Tìm kiếm')) {
          categoryIcon = Icons.search_rounded;
        } else if (categoryName.contains('Đăng tin')) {
          categoryIcon = Icons.add_home_work_rounded;
        } else if (categoryName.contains('Tài khoản')) {
          categoryIcon = Icons.security_rounded;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
              child: Row(
                children: [
                  Icon(categoryIcon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    categoryName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            ...categoryItems.map((item) => _buildFAQTile(item)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildFAQTile(_FAQItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textMuted,
          title: Text(
            item.question,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.borderLight, width: 0.8),
                ),
              ),
              child: Text(
                item.answer,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.search_off_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không tìm thấy kết quả',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              'Không tìm thấy câu hỏi phù hợp với từ khóa "$_searchQuery". Vui lòng thử từ khóa khác.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
