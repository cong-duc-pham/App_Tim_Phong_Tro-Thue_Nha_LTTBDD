import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';
import '../../services/search_history_service.dart';

class SearchHistoryScreen extends StatefulWidget {
  const SearchHistoryScreen({super.key});

  @override
  State<SearchHistoryScreen> createState() => _SearchHistoryScreenState();
}

class _SearchHistoryScreenState extends State<SearchHistoryScreen> {
  List<String> _historyList = [];
  bool _isLoading = true;

  // Danh sách từ khóa gợi ý phổ biến cho người dùng tìm kiếm nhanh
  static const List<String> _popularSuggestions = [
    'Quận 10',
    'Phòng trọ giá rẻ',
    'Gần Đại học',
    'Cho nuôi thú cưng',
    'Quận Bình Thạnh',
    'Phòng trọ VIP',
    'Căn hộ mini',
    'Gần trạm xe buýt'
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  // Tải danh sách lịch sử từ SharedPreferences
  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await SearchHistoryService.getHistory();
    setState(() {
      _historyList = history;
      _isLoading = false;
    });
  }

  // Xử lý khi nhấn vào từ khóa để tìm kiếm lại
  Future<void> _onSelectKeyword(String keyword) async {
    // Đẩy từ khóa này lên đầu lịch sử tìm kiếm gần đây
    await SearchHistoryService.addHistory(keyword);
    if (!mounted) return;

    // Điều hướng quay lại Trang chủ kèm tham số truy vấn tìm kiếm
    context.go('/home?q=${Uri.encodeComponent(keyword)}');
  }

  // Xóa một từ khóa cụ thể ra khỏi lịch sử
  Future<void> _deleteItem(String keyword) async {
    await SearchHistoryService.removeHistory(keyword);
    // Tải lại danh sách mới để cập nhật giao diện
    final updatedList = await SearchHistoryService.getHistory();
    setState(() {
      _historyList = updatedList;
    });
  }

  // Xóa toàn bộ lịch sử tìm kiếm (hiển thị hộp thoại xác nhận)
  Future<void> _clearAllHistory() async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        title: Text('clear_search_confirm_title'.tr,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text('clear_search_confirm_desc'.tr),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await SearchHistoryService.clearHistory();
              setState(() {
                _historyList = [];
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('clear'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _historyList.isEmpty
                    ? _buildEmptyState()
                    : _buildHistoryList(),
          ),
        ],
      ),
    );
  }

  // Header đồng bộ thiết kế với góc bo tròn mềm mại và màu chủ đạo
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
                    'profile_search_history'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  // Chỉ hiển thị nút xóa tất cả khi có dữ liệu lịch sử
                  if (_historyList.isNotEmpty)
                    GestureDetector(
                      onTap: _clearAllHistory,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusMd),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.delete_sweep_rounded,
                                color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              'clear'.tr,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
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

  // Hiển thị danh sách lịch sử tìm kiếm dạng cuộn
  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _historyList.length + 1,
      itemBuilder: (context, index) {
        if (index == _historyList.length) {
          // Phần gợi ý từ khóa nằm ở cuối danh sách lịch sử để tăng tính tương tác
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildSuggestionsSection(),
              const SizedBox(height: 32),
            ],
          );
        }

        final keyword = _historyList[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: context.profileCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: context.profileBorder),
          ),
          child: Row(
            children: [
              // Khu vực chứa Text từ khóa chiếm phần lớn dòng và có touch target rộng
              Expanded(
                child: InkWell(
                  onTap: () => _onSelectKeyword(keyword),
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppConstants.radiusMd),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          color: context.profileTextMuted,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            keyword,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: context.profileText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Nút xóa riêng lẻ ở bên phải với Touch Target độc lập và rộng rãi (tối thiểu 48px)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _deleteItem(keyword),
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(AppConstants.radiusMd),
                  ),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      color: context.profileTextMuted,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Trạng thái trống (Empty State) hiển thị khi chưa thực hiện tìm kiếm nào
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
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
            'search_history_empty_title'.tr,
            style: AppTextStyles.h3.copyWith(color: context.profileText),
          ),
          const SizedBox(height: 8),
          Text(
            'search_history_empty_desc'.tr,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.profileTextSecondary,
            ),
          ),
          const SizedBox(height: 40),
          _buildSuggestionsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Widget hiển thị danh sách từ khóa gợi ý dạng Wrap (Chip)
  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'search_history_suggestions'.tr,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.profileText,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularSuggestions.map((suggestion) {
            return InkWell(
              onTap: () => _onSelectKeyword(suggestion),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: context.profileCard,
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                  border: Border.all(color: context.profileBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up_rounded,
                      color: AppColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.profileTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
