import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/conversation.dart';
import '../../repositories/message_repository.dart';
import '../../services/chat_unread_service.dart';

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final MessageRepository _messageRepo = MessageRepository();
  final TextEditingController _searchCtrl = TextEditingController();
  
  List<Conversation> _allConversations = [];
  List<Conversation> _filteredConversations = [];
  String _searchQuery = '';
  String _selectedTab = 'all';
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _setupSignalR();
  }

  @override
  void dispose() {
    _messageRepo.disconnectFromChatHub();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _setupSignalR() async {
    try {
      await _messageRepo.connectToChatHub(
        onMessageReceived: (msg) {
          if (mounted) {
            _loadConversations(silent: true);
          }
        },
        onMessageSentConfirm: (msg) {
          if (mounted) {
            _loadConversations(silent: true);
          }
        },
        onMessagesReadByOther: (convId) {
          if (mounted) {
            _loadConversations(silent: true);
          }
        },
      );
    } catch (_) {}
  }

  Future<void> _loadConversations({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final conversations = await _messageRepo.getConversations();
      if (!mounted) return;
      ChatUnreadService.setFromConversations(conversations);
      setState(() {
        _allConversations = conversations;
        _isLoading = false;
      });
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(e);
        _isLoading = false;
        _loadMockConversations();
      });
    }
  }

  void _loadMockConversations() {
    _allConversations = [
      Conversation(
        convId: 101,
        landlordId: 10,
        tenantId: 1,
        listingId: 50001,
        otherUserId: 10,
        otherUserName: 'Nguyễn Văn A (Chủ nhà)',
        otherUserAvatar: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=150&q=80',
        listingTitle: 'Phòng trọ cao cấp Q7 gần Lotte Mart',
        listingImage: 'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&w=600&q=80',
        lastMessage: 'Hình ảnh phòng chụp sáng nay',
        lastMsgAt: DateTime.now().subtract(const Duration(minutes: 44)),
        unreadCount: 0,
      ),
      Conversation(
        convId: 102,
        landlordId: 12,
        tenantId: 1,
        listingId: 50002,
        otherUserId: 12,
        otherUserName: 'Trần Thị B (Chủ nhà)',
        otherUserAvatar: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=150&q=80',
        listingTitle: 'Chung cư mini lầu 2, không chung chủ Quận 1',
        listingImage: 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=600&q=80',
        lastMessage: 'Bạn có muốn qua xem phòng chiều nay không?',
        lastMsgAt: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 1,
      ),
    ];
    ChatUnreadService.setFromConversations(_allConversations);
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _allConversations.where((conv) {
      final matchesQuery = query.isEmpty ||
          conv.otherUserName.toLowerCase().contains(query) ||
          (conv.listingTitle?.toLowerCase().contains(query) ?? false) ||
          (conv.lastMessage?.toLowerCase().contains(query) ?? false);

      if (!matchesQuery) return false;
      if (_selectedTab == 'unread') return conv.unreadCount > 0;
      return true;
    }).toList();

    filtered.sort((a, b) {
      if (a.lastMsgAt == null) return 1;
      if (b.lastMsgAt == null) return -1;
      return b.lastMsgAt!.compareTo(a.lastMsgAt!);
    });

    setState(() => _filteredConversations = filtered);
  }

  String _cleanError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
            }
          },
        ),
        title: const Text(
          'Tin nhắn',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadConversations(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null && _allConversations.isEmpty) {
      return _buildStateBox(
        icon: Icons.wifi_off_rounded,
        title: 'Không tải được tin nhắn',
        message: _errorMessage!,
        actionLabel: 'Thử lại',
        onAction: () => _loadConversations(),
      );
    }

    if (_filteredConversations.isEmpty) {
      return _buildStateBox(
        icon: Icons.chat_bubble_outline_rounded,
        title:
            _searchQuery.isEmpty ? 'Chưa có cuộc trò chuyện' : 'Không tìm thấy',
        message: _searchQuery.isEmpty
            ? 'Khi bạn nhắn tin với chủ phòng, hội thoại sẽ hiển thị tại đây.'
            : 'Thử tìm bằng tên người dùng, tin đăng hoặc nội dung khác.',
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _loadConversations(silent: true),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: _filteredConversations.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _buildConversationCard(_filteredConversations[index]);
        },
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              decoration: InputDecoration(
                hintText: 'Tìm người dùng, tin đăng, nội dung...',
                hintStyle:
                    const TextStyle(color: AppColors.textMuted, fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchQuery = '';
                          _applyFilters();
                        },
                        icon: const Icon(Icons.clear_rounded, size: 18),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildTabButton(id: 'all', label: 'Tất cả'),
              const SizedBox(width: 8),
              _buildTabButton(id: 'unread', label: 'Chưa đọc'),
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
          _selectedTab = id;
          _applyFilters();
        },
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
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

  Widget _buildConversationCard(Conversation conv) {
    final hasUnread = conv.unreadCount > 0;
    final formattedTime = _formatMsgTime(conv.lastMsgAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/chat/detail', extra: conv).then((_) {
            if (mounted) _loadConversations(silent: true);
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
          ),
          child: Row(
            children: [
              _buildAvatar(conv),
              const SizedBox(width: 12),
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
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                  hasUnread ? FontWeight.w700 : FontWeight.w500,
                            color: hasUnread
                                ? AppColors.primary
                                : AppColors.textMuted,
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
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                        color: hasUnread
                            ? AppColors.textDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    if (conv.listingTitle != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.home_outlined,
                              size: 12, color: AppColors.primary),
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
              if (hasUnread)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.notifDot,
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: Text(
                    '${conv.unreadCount}',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(Conversation conv) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border, width: 2),
        color: AppColors.bgCardLight,
      ),
      child: conv.otherUserAvatar != null
          ? ClipOval(
              child: Image.network(
                conv.otherUserAvatar!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _buildAvatarPlaceholder(conv.otherUserName),
              ),
            )
          : _buildAvatarPlaceholder(conv.otherUserName),
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    final initials = name
        .trim()
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((e) => e[0])
        .take(2)
        .join('')
        .toUpperCase();
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

  Widget _buildStateBox({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatMsgTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final difference = now.difference(date.toLocal());

    if (difference.inMinutes < 1) return 'Vừa xong';
    if (difference.inHours < 1) return '${difference.inMinutes} phút trước';
    if (difference.inDays < 1 && date.day == now.day) {
      final minuteString =
          date.minute < 10 ? '0${date.minute}' : '${date.minute}';
      return '${date.hour}:$minuteString';
    }
    if (difference.inDays < 2) return 'Hôm qua';
    return '${date.day}/${date.month}/${date.year}';
  }
}
