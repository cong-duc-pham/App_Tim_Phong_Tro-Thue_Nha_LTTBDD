import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';

enum LegalDocumentType {
  terms,
  privacy,
}

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.type,
  });

  final LegalDocumentType type;

  bool get _isTerms => type == LegalDocumentType.terms;

  String get _title => _isTerms ? 'Điều khoản sử dụng' : 'Chính sách bảo mật';

  String get _subtitle => _isTerms
      ? 'Các quy định khi sử dụng Swings House'
      : 'Cách Swings House thu thập, sử dụng và bảo vệ dữ liệu của bạn';

  List<_LegalSection> get _sections =>
      _isTerms ? _termsSections : _privacySections;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.paddingH,
                  AppConstants.spacingMd,
                  AppConstants.paddingH,
                  AppConstants.spacingXxl,
                ),
                itemBuilder: (context, index) {
                  final section = _sections[index];
                  return _LegalSectionView(section: section);
                },
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppConstants.spacingMd),
                itemCount: _sections.length,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.paddingH,
        AppConstants.spacingLg,
        AppConstants.paddingH,
        AppConstants.spacingSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingXl),
          Text(_title, style: AppTextStyles.h1),
          const SizedBox(height: AppConstants.spacingXs),
          Text(_subtitle, style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppConstants.spacingSm),
          const Text(
            'Cập nhật lần cuối: 05/06/2026',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _LegalSectionView extends StatelessWidget {
  const _LegalSectionView({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingLg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: AppTextStyles.h3),
          const SizedBox(height: AppConstants.spacingSm),
          ...section.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingXs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: SizedBox(
                      width: 5,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  Expanded(
                    child: Text(item, style: AppTextStyles.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;
}

const _termsSections = [
  _LegalSection(
    title: '1. Chấp nhận điều khoản',
    items: [
      'Khi tạo tài khoản hoặc sử dụng Swings House, bạn đồng ý tuân thủ các điều khoản sử dụng này.',
      'Nếu không đồng ý với điều khoản, bạn có thể ngừng đăng ký hoặc ngừng sử dụng ứng dụng.',
    ],
  ),
  _LegalSection(
    title: '2. Tài khoản người dùng',
    items: [
      'Bạn cần cung cấp thông tin chính xác khi đăng ký, bao gồm họ tên, số điện thoại và email.',
      'Bạn chịu trách nhiệm bảo mật mật khẩu và các hoạt động phát sinh từ tài khoản của mình.',
      'Swings House có thể yêu cầu xác thực số điện thoại hoặc email trước khi sử dụng một số tính năng.',
    ],
  ),
  _LegalSection(
    title: '3. Nội dung tin đăng',
    items: [
      'Tin đăng cần phản ánh đúng thông tin phòng trọ, giá thuê, vị trí, hình ảnh và điều kiện thuê.',
      'Không đăng nội dung giả mạo, lừa đảo, vi phạm pháp luật, xúc phạm cá nhân hoặc gây hiểu nhầm cho người thuê.',
      'Swings House có quyền ẩn, từ chối hoặc gỡ tin đăng vi phạm quy định.',
    ],
  ),
  _LegalSection(
    title: '4. Giao dịch và liên hệ',
    items: [
      'Swings House hỗ trợ kết nối người thuê và chủ phòng, nhưng không trực tiếp bảo đảm mọi thỏa thuận giữa hai bên.',
      'Người dùng nên kiểm tra thông tin phòng, giấy tờ và điều kiện thuê trước khi đặt cọc hoặc thanh toán.',
    ],
  ),
  _LegalSection(
    title: '5. Thay đổi điều khoản',
    items: [
      'Điều khoản có thể được cập nhật để phù hợp với tính năng mới hoặc yêu cầu vận hành.',
      'Việc tiếp tục sử dụng ứng dụng sau khi điều khoản được cập nhật được xem là bạn đồng ý với nội dung mới.',
    ],
  ),
];

const _privacySections = [
  _LegalSection(
    title: '1. Thông tin chúng tôi thu thập',
    items: [
      'Thông tin tài khoản như họ tên, số điện thoại, email và trạng thái xác thực.',
      'Thông tin sử dụng ứng dụng như tin đăng đã xem, phòng yêu thích, lịch sử tìm kiếm và tùy chọn tìm phòng.',
      'Thông tin thiết bị cần thiết cho thông báo, bảo mật đăng nhập và cải thiện trải nghiệm.',
    ],
  ),
  _LegalSection(
    title: '2. Mục đích sử dụng dữ liệu',
    items: [
      'Tạo và quản lý tài khoản, xác thực người dùng và bảo vệ tài khoản.',
      'Hiển thị tin đăng phù hợp, lưu phòng yêu thích, hỗ trợ nhắn tin và gửi thông báo cần thiết.',
      'Phát hiện hành vi bất thường, xử lý báo cáo vi phạm và cải thiện chất lượng dịch vụ.',
    ],
  ),
  _LegalSection(
    title: '3. Chia sẻ thông tin',
    items: [
      'Một số thông tin liên hệ có thể được hiển thị trong tin đăng hoặc cuộc trò chuyện để người thuê và chủ phòng liên hệ.',
      'Swings House không bán dữ liệu cá nhân của người dùng cho bên thứ ba.',
      'Dữ liệu có thể được chia sẻ khi cần tuân thủ quy định pháp luật hoặc xử lý yêu cầu bảo mật hợp lệ.',
    ],
  ),
  _LegalSection(
    title: '4. Bảo mật dữ liệu',
    items: [
      'Chúng tôi sử dụng các biện pháp kỹ thuật phù hợp để hạn chế truy cập trái phép vào dữ liệu người dùng.',
      'Mật khẩu và token đăng nhập cần được người dùng tự bảo vệ, không chia sẻ cho người khác.',
      'Nếu phát hiện rủi ro bảo mật, người dùng nên đổi mật khẩu và liên hệ bộ phận hỗ trợ.',
    ],
  ),
  _LegalSection(
    title: '5. Quyền của người dùng',
    items: [
      'Bạn có thể cập nhật thông tin cá nhân trong hồ sơ tài khoản.',
      'Bạn có thể đăng xuất, đổi mật khẩu hoặc yêu cầu hỗ trợ khi muốn chỉnh sửa hoặc ngừng sử dụng tài khoản.',
      'Mọi thắc mắc về bảo mật có thể gửi đến đội ngũ Swings House để được hỗ trợ.',
    ],
  ),
];
