import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';

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
      answer:
          'Bạn có thể nhập tên trường hoặc khu vực vào ô tìm kiếm ở trang chủ. Sử dụng bộ lọc nâng cao để chọn khoảng giá, diện tích và các tiện ích mong muốn.',
    ),
    _FAQItem(
      category: 'Tìm kiếm & Thuê phòng',
      question: 'Tôi muốn đặt cọc giữ chỗ thì có an toàn không?',
      answer:
          'Để đảm bảo an toàn, bạn nên hẹn chủ nhà xem phòng thực tế trước khi đặt cọc. Nên yêu cầu giấy tờ biên nhận đặt cọc rõ ràng và không chuyển khoản trước cho người lạ.',
    ),
    _FAQItem(
      category: 'Tìm kiếm & Thuê phòng',
      question: 'Làm thế nào để lưu lại các phòng trọ tôi yêu thích?',
      answer:
          'Bạn có thể nhấn vào biểu tượng trái tim (Favorite) ở góc các thẻ phòng trọ. Danh sách phòng đã lưu sẽ hiển thị trong trang Cá nhân -> Phòng đã lưu hoặc tab Yêu thích dưới thanh điều hướng.',
    ),

    // Category: Đăng tin & Chủ nhà
    _FAQItem(
      category: 'Đăng tin & Chủ nhà',
      question: 'Làm sao để đăng tin cho thuê phòng trọ?',
      answer:
          'Bạn hãy chuyển đổi tài khoản sang vai trò "Chủ nhà" trong phần thông tin cá nhân. Sau đó nhấn nút "+" (Đăng tin) ở thanh điều hướng dưới cùng để điền thông tin phòng.',
    ),
    _FAQItem(
      category: 'Đăng tin & Chủ nhà',
      question: 'Tin đăng VIP khác gì so với tin đăng thường?',
      answer:
          'Tin VIP sẽ được ghim ở đầu trang chủ, hiển thị nổi bật với nhãn màu xanh và được hệ thống ưu tiên tiếp cận gấp 5 lần so với tin đăng thông thường.',
    ),
    _FAQItem(
      category: 'Đăng tin & Chủ nhà',
      question: 'Tôi có thể đăng tối đa bao nhiêu ảnh cho một phòng trọ?',
      answer:
          'Đối với gói tin đăng miễn phí, bạn có thể tải lên tối đa 1 ảnh. Với các gói tin đăng VIP hoặc Featured, bạn có thể tải lên từ 10 đến không giới hạn số lượng ảnh chất lượng cao để thu hút người thuê.',
    ),

    // Category: Tài khoản & Bảo mật
    _FAQItem(
      category: 'Tài khoản & Bảo mật',
      question: 'Làm thế nào để xác thực tài khoản (Verified Badge)?',
      answer:
          'Trong trang Cá nhân, nhấn vào mục "Xác thực tài khoản" và tải lên ảnh căn cước công dân hoặc giấy tờ xác minh cần thiết. Đội ngũ kiểm duyệt sẽ xử lý trong vòng 24 giờ.',
    ),
    _FAQItem(
      category: 'Tài khoản & Bảo mật',
      question: 'Tôi quên mật khẩu đăng nhập phải làm sao?',
      answer:
          'Tại màn hình Đăng nhập, chọn "Quên mật khẩu", nhập email đăng ký của bạn. Hệ thống sẽ gửi một liên kết đặt lại mật khẩu về email đó.',
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
      backgroundColor: context.profileBg,
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
                  Text(
                    'profile_support_center'.tr,
                    style: const TextStyle(
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
              decoration: BoxDecoration(
                color: context.profileBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
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
          color: context.profileInputFill,
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
          style: TextStyle(fontSize: 14, color: context.profileText),
          decoration: InputDecoration(
            hintText: 'support_search_hint'.tr,
            hintStyle: AppTextStyles.inputHint.copyWith(
              color: context.profileTextMuted,
            ),
            prefixIcon: Icon(Icons.search_rounded,
                color: context.profileTextMuted, size: 20),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: context.profileTextMuted, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: context.profileInputFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFAQContent(List<_FAQItem> faqs) {
    if (_searchQuery.trim().isNotEmpty) {
      // Khi đang tìm kiếm, hiển thị danh sách phẳng trực quan kèm contact card ở cuối
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: faqs.length + 1,
        itemBuilder: (context, index) {
          if (index == faqs.length) {
            return Column(
              children: [
                const SizedBox(height: 16),
                _buildContactCard(),
              ],
            );
          }
          return _buildFAQTile(faqs[index]);
        },
      );
    }

    // Khi không tìm kiếm, nhóm các câu hỏi theo danh mục
    final Map<String, List<_FAQItem>> groupedFAQs = {};
    for (var item in faqs) {
      groupedFAQs.putIfAbsent(item.category, () => []).add(item);
    }

    final List<Widget> listWidgets = [];
    groupedFAQs.forEach((categoryName, categoryItems) {
      IconData categoryIcon = Icons.help_center_rounded;
      if (categoryName.contains('Tìm kiếm')) {
        categoryIcon = Icons.search_rounded;
      } else if (categoryName.contains('Đăng tin')) {
        categoryIcon = Icons.add_home_work_rounded;
      } else if (categoryName.contains('Tài khoản')) {
        categoryIcon = Icons.security_rounded;
      }

      listWidgets.add(
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
          child: Row(
            children: [
              Icon(categoryIcon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                categoryName.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.profileTextSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      );

      listWidgets.addAll(categoryItems.map((item) => _buildFAQTile(item)));
      listWidgets.add(const SizedBox(height: 8));
    });

    // Thêm contact card ở cuối danh mục
    listWidgets.add(const SizedBox(height: 8));
    listWidgets.add(_buildContactCard());
    listWidgets.add(const SizedBox(height: 16));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: listWidgets,
    );
  }

  Widget _buildFAQTile(_FAQItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: context.profileBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: context.profileTextMuted,
          title: Text(
            item.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.profileText,
              height: 1.4,
            ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: context.profileBorder, width: 0.8),
                ),
              ),
              child: Text(
                item.answer,
                style: TextStyle(
                  fontSize: 13,
                  color: context.profileTextSecondary,
                  height: 1.55,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            'support_need_help'.tr,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryMedium,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'support_contact_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.profileTextSecondary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildSupportAction(
                icon: Icons.phone_rounded,
                label: 'Hotline',
                color: AppColors.success,
                onTap: _callHotline,
              ),
              const SizedBox(width: 12),
              _buildSupportAction(
                icon: Icons.email_rounded,
                label: 'Email',
                color: AppColors.info,
                onTap: _sendEmail,
              ),
              const SizedBox(width: 12),
              _buildSupportAction(
                icon: Icons.bug_report_rounded,
                label: 'support_report_bug'.tr,
                color: AppColors.error,
                onTap: () => context.push(AppConstants.routeReportIssue),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSupportAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: context.profileCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: context.profileBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.profileText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _callHotline() async {
    final Uri phoneUri = Uri(scheme: 'tel', path: '19001234');

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: const Text('Gọi tổng đài hỗ trợ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Tổng đài hỗ trợ 24/7 của SWING HOUSE:\n\n📞 1900 1234 (1.000đ/phút)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (await canLaunchUrl(phoneUri)) {
                  await launchUrl(phoneUri);
                } else {
                  throw 'Không thể gọi số này';
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Không thể khởi chạy cuộc gọi (Lỗi: $e). Số hotline: 1900 1234'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Gọi ngay'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@swinghouse.vn',
      queryParameters: {
        'subject': 'Yêu cầu hỗ trợ từ ứng dụng SWING HOUSE',
      },
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: const Text('Gửi email hỗ trợ?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Gửi yêu cầu hỗ trợ đến email:\n\n✉️ support@swinghouse.vn'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                if (await canLaunchUrl(emailUri)) {
                  await launchUrl(emailUri);
                } else {
                  throw 'Không tìm thấy ứng dụng email tương thích';
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Không thể gửi mail (Lỗi: $e). Vui lòng gửi thủ công đến support@swinghouse.vn'),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Gửi mail'),
          ),
        ],
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
            Text(
              'support_no_result'.tr,
              style: AppTextStyles.h3.copyWith(color: context.profileText),
            ),
            const SizedBox(height: 8),
            Text(
              'Không tìm thấy câu hỏi phù hợp với từ khóa "$_searchQuery". Vui lòng thử từ khóa khác.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: context.profileTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildContactCard(),
          ],
        ),
      ),
    );
  }
}
