// lib/screens/chat/conversations_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/conversation.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late List<Conversation> _allConversations;
  late List<Conversation> _filteredConversations;
  String _searchQuery = '';
  String _selectedTab = 'all'; // 'all', 'unread', 'landlord'

  @override
  void initState() {
    super.initState();
    _loadMockConversations();
  }

  void _loadMockConversations() {
    _allConversations = [
      Conversation(
        convId: 101,
        listingId: 201,
        listingTitle: 'Phòng trọ cao cấp gác lửng Quận 7, Full nội thất',
        listingImage: 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&w=120&q=80',
        lastMessage: 'Dạ anh ơi, chiều nay 5h em qua xem phòng được không ạ?',
        lastMsgAt: DateTime.now().subtract(const Duration(minutes: 12)),
        otherUserId: 301,
        otherUserName: 'Anh Thành Đạt (Chủ nhà)',
        otherUserAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
        unreadCount: 2,
      ),
      Conversation(
        convId: 102,
        listingId: 202,
        listingTitle: 'Căn hộ dịch vụ studio Bình Thạnh, ban công thoáng mát',
        listingImage: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=120&q=80',
        lastMessage: 'Tiền cọc phòng là 2 tháng em nhé, có thể đóng trước 1 tháng.',
        lastMsgAt: DateTime.now().subtract(const Duration(hours: 2)),
        otherUserId: 302,
        otherUserName: 'Chị Mai Vy (Chủ nhà)',
        otherUserAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=120&q=80',
        unreadCount: 0,
      ),
      Conversation(
        convId: 103,
        listingId: 203,
        listingTitle: 'Phòng trọ ghép gần ĐHQG Thủ Đức, bao điện nước',
        listingImage: 'https://images.unsplash.com/photo-1564013799919-ab600027ffc6?auto=format&fit=crop&w=120&q=80',
        lastMessage: 'Ok bạn nha, phòng này hiện tại còn 1 slot nam thôi.',
        lastMsgAt: DateTime.now().subtract(const Duration(days: 1)),
        otherUserId: 303,
        otherUserName: 'Quốc Bảo (Ở ghép)',
        otherUserAvatar: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=120&q=80',
        unreadCount: 0,
      ),
      Conversation(
        convId: 104,
        listingId: 204,
        listingTitle: 'Nhà nguyên căn 3 phòng ngủ Quận 9, thích hợp ở hộ gia đình',
        listingImage: 'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?auto=format&fit=crop&w=120&q=80',
        lastMessage: 'Tin nhắn này chưa được đọc nè!',
        lastMsgAt: DateTime.now().subtract(const Duration(days: 2)),
        otherUserId: 304,
        otherUserName: 'Chú Ba Đất Đai (Chủ nhà)',
        otherUserAvatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=120&q=80',
        unreadCount: 5,
      ),
    ];
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredConversations = _allConversations.where((conv) {
        // Search filter
        final nameMatch = conv.otherUserName.toLowerCase().contains(_searchQuery.toLowerCase());
        final titleMatch = conv.listingTitle?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        final msgMatch = conv.lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
        final isMatchSearch = nameMatch || titleMatch || msgMatch;

        if (!isMatchSearch) return false;

        // Tab filter
        if (_selectedTab == 'unread') {
          return conv.unreadCount > 0;
        } else if (_selectedTab == 'landlord') {
          return conv.otherUserName.contains('Chủ nhà');
        }

        return true;
      }).toList();

      // Sort by last message date (newest first)
      _filteredConversations.sort((a, b) {
        if (a.lastMsgAt == null) return 1;
        if (b.lastMsgAt == null) return -1;
        return b.lastMsgAt!.compareTo(a.lastMsgAt!);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
        title: const Text(
          'Tin nhắn',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              // Reset list simulation
              _loadMockConversations();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã cập nhật danh sách cuộc hội thoại!'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Tải lại cuộc trò chuyện',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(
            child: _filteredConversations.isEmpty
                ? _buildEmptyState()
                : _buildConversationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          // Search Box
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Tìm người dùng, tin đăng, nội dung...',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            _searchQuery = '';
                          });
                          _applyFilters();
                        },
                        child: const Icon(Icons.clear_rounded, color: AppColors.textSecondary, size: 18),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
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
          const SizedBox(height: 16),
          // Horizontal Custom Segment Tabs
          Row(
            children: [
              _buildTabButton(id: 'all', label: 'Tất cả'),
              const SizedBox(width: 8),
              _buildTabButton(id: 'unread', label: 'Chưa đọc'),
              const SizedBox(width: 8),
              _buildTabButton(id: 'landlord', label: 'Chủ nhà'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({required String id, required String label}) {
    final isSelected = _selectedTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTab = id;
          });
          _applyFilters();
        },
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationsList() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _filteredConversations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final conv = _filteredConversations[index];
          return _buildConversationCard(conv);
        },
      ),
    );
  }

  Widget _buildConversationCard(Conversation conv) {
    final hasUnread = conv.unreadCount > 0;
    final formattedTime = _formatMsgTime(conv.lastMsgAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to details chat screen
          context.push('/chat/detail', extra: conv).then((_) {
            // Refresh counts/mock data on return if simulated updates happened
            _loadMockConversations();
          });
        },
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: hasUnread ? AppColors.primaryLight : AppColors.borderLight,
              width: hasUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: hasUnread 
                    ? AppColors.primary.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.01),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with active status dot
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hasUnread ? AppColors.primary : AppColors.border,
                        width: 2,
                      ),
                      color: AppColors.bgCardLight,
                    ),
                    child: conv.otherUserAvatar != null
                        ? ClipOval(
                            child: Image.network(
                              conv.otherUserAvatar!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(conv.otherUserName),
                            ),
                          )
                        : _buildAvatarPlaceholder(conv.otherUserName),
                  ),
                  // Online indicator (simulated)
                  Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Message text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conv.otherUserName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color: hasUnread ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conv.lastMessage ?? 'Chưa có tin nhắn',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                        color: hasUnread ? AppColors.textDark : AppColors.textSecondary,
                      ),
                    ),
                    if (conv.listingTitle != null) ...[
                      const SizedBox(height: 6),
                      // Row linking listing title info
                      Row(
                        children: [
                          const Icon(Icons.home_outlined, size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              conv.listingTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Listing thumbnail and unread badge column
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (conv.listingImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                      child: Image.network(
                        conv.listingImage!,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(Icons.home_work_rounded, size: 24, color: AppColors.textMuted),
                      ),
                    ),
                  const SizedBox(height: 6),
                  if (hasUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.notifDot,
                        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${conv.unreadCount}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 15), // Placeholder spacing
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    final initials = name.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase();
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Không tìm thấy cuộc hội thoại',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Vui lòng kiểm tra lại từ khóa tìm kiếm của bạn.'
                  : 'Hãy nhắn tin hỏi các chủ nhà về phòng trọ bạn quan tâm nhé!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMsgTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Vừa xong';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} phút trước';
    } else if (difference.inDays < 1 && date.day == now.day) {
      final minuteString = date.minute < 10 ? '0${date.minute}' : '${date.minute}';
      return '${date.hour}:$minuteString';
    } else if (difference.inDays < 2 && date.day == now.subtract(const Duration(days: 1)).day) {
      return 'Hôm qua';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
