import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/conversation.dart';
import '../../repositories/message_repository.dart';
import '../../services/chat_unread_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';

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
      backgroundColor: context.profileBg,
      appBar: AppBar(
        backgroundColor: context.isDarkProfile ? context.profileCard : AppColors.primary,
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
        title: Text(
          'chat_title'.tr,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () => _loadConversations(),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'chat_reload_tooltip'.tr,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndFilters(),
          _buildAiAssistantCard(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildAiAssistantCard() {
    return Material(
      color: context.profileBg,
      child: InkWell(
        onTap: () => context.push(AppConstants.routeAiChat),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF6C63FF)],
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white24,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Trợ lý AI tìm phòng',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Hỏi về ngân sách, khu vực, hợp đồng và đặt cọc',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
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
        title: 'chat_load_error_title'.tr,
        message: _errorMessage!,
        actionLabel: 'common_retry'.tr,
        onAction: () => _loadConversations(),
      );
    }

    if (_filteredConversations.isEmpty) {
      return _buildStateBox(
        icon: Icons.chat_bubble_outline_rounded,
        title:
            _searchQuery.isEmpty ? 'chat_empty_title'.tr : 'chat_search_empty_title'.tr,
        message: _searchQuery.isEmpty
            ? 'chat_empty_desc'.tr
            : 'chat_search_empty_desc'.tr,
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
      color: context.isDarkProfile ? context.profileCard : AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: context.profileInputFill,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: context.isDarkProfile ? Border.all(color: context.profileBorder) : null,
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
              style: TextStyle(color: context.profileText),
              decoration: InputDecoration(
                hintText: 'chat_search_hint'.tr,
                hintStyle:
                    TextStyle(color: context.profileTextMuted, fontSize: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: context.profileTextSecondary,
                  size: 20,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchCtrl.clear();
                          _searchQuery = '';
                          _applyFilters();
                        },
                        icon: Icon(Icons.clear_rounded, color: context.profileTextSecondary, size: 18),
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
              _buildTabButton(id: 'all', label: 'chat_tab_all'.tr),
              const SizedBox(width: 8),
              _buildTabButton(id: 'unread', label: 'chat_tab_unread'.tr),
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
                ? (context.isDarkProfile ? AppColors.primary : Colors.white)
                : (context.isDarkProfile ? context.profileInputFill : Colors.white.withValues(alpha: 0.15)),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            border: (!isSelected && context.isDarkProfile) ? Border.all(color: context.profileBorder) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? (context.isDarkProfile ? Colors.white : AppColors.primary)
                  : (context.isDarkProfile ? context.profileTextSecondary : Colors.white),
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
            color: context.profileCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: hasUnread ? AppColors.primary : context.profileBorder,
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
                              color: context.profileText,
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
                                : context.profileTextMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conv.lastMessage ?? 'chat_no_messages'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            hasUnread ? FontWeight.w600 : FontWeight.w400,
                        color: hasUnread
                            ? context.profileText
                            : context.profileTextSecondary,
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
        border: Border.all(color: context.profileBorder, width: 2),
        color: context.profileSubtleCard,
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
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: context.isDarkProfile ? context.profileText : AppColors.primary,
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
              decoration: BoxDecoration(
                color: context.isDarkProfile ? context.profileSubtleCard : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.profileText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.profileTextSecondary,
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

    if (difference.inMinutes < 1) return 'chat_time_just_now'.tr;
    if (difference.inHours < 1) return 'chat_time_minutes_ago'.tr.replaceAll('{minutes}', '${difference.inMinutes}');
    if (difference.inDays < 1 && date.day == now.day) {
      final minuteString =
          date.minute < 10 ? '0${date.minute}' : '${date.minute}';
      return '${date.hour}:$minuteString';
    }
    if (difference.inDays < 2) return 'chat_time_yesterday'.tr;
    return '${date.day}/${date.month}/${date.year}';
  }
}
