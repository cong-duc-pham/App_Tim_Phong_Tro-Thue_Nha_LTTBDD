// lib/screens/chat/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../repositories/message_repository.dart';
import '../../repositories/conversation_repository.dart';
import '../../repositories/listing_repository.dart';
import '../../services/chat_unread_service.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Message> _messages = [];
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final bool _isTyping = false;
  bool _isSending = false;
  String? _errorMessage;
  bool _showListingHeader = true;
  int _currentUserId = 999; // Lấy từ SharedPreferences hoặc fallback 999
  int? _listingLandlordId;
  double? _listingPrice;
  double? _listingArea;
  bool _isListingRented = false;
  bool _canConfirmRental = false;
  bool _isConnected = true;
  bool _isLoading = true;
  final _messageRepo = MessageRepository();

  bool get _isListingUnavailable =>
      widget.conversation.listingId == null ||
      widget.conversation.listingId == 0;

  @override
  void initState() {
    super.initState();
    _isListingRented =
        widget.conversation.listingStatusName?.toLowerCase().trim() == 'rented';
    _canConfirmRental =
        widget.conversation.canConfirmRental ?? !_isListingRented;
    _loadCurrentUserId().then((_) {
      _loadRealMessages();
      _setupRealTimeChat();
      _fetchListingLandlordId();
    });
  }

  Future<void> _fetchListingLandlordId() async {
    final listingId = widget.conversation.listingId;
    if (listingId != null && listingId != 0) {
      try {
        final repo = ListingRepository();
        final listing = await repo.getListing(listingId);
        if (listing != null && mounted) {
          final isRented = listing.statusName.toLowerCase().trim() == 'rented';
          setState(() {
            _listingLandlordId = listing.landlordId;
            _listingPrice = listing.price;
            _listingArea = listing.area;
            _isListingRented = isRented;
            _canConfirmRental =
                (widget.conversation.canConfirmRental ?? !isRented) &&
                    !isRented;
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _messageRepo.disconnectFromChatHub();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idStr = prefs.getString(AppConstants.keyUserId);
      if (idStr != null) {
        final idVal = int.tryParse(idStr);
        if (idVal != null) {
          setState(() {
            _currentUserId = idVal;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadRealMessages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final list = await _messageRepo.getMessages(widget.conversation.convId);
      if (!mounted) return;
      ChatUnreadService.markConversationRead(widget.conversation);
      setState(() {
        _messages.clear();
        _messages.addAll(list);
        _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
        _isLoading = false;
      });
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _scrollToBottom(animated: false));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _cleanError(e);
        // Fallback to mock messages for offline / demo
        _loadMockMessages();
      });
    }
  }

  void _setupRealTimeChat() async {
    try {
      await _messageRepo.connectToChatHub(
        onConnectionStateChanged: (connected) {
          if (mounted) {
            setState(() {
              _isConnected = connected;
            });
          }
        },
        onMessageReceived: (msg) {
          if (msg.convId == widget.conversation.convId) {
            if (!mounted) return;
            setState(() => _upsertMessage(msg));
            _scrollToBottom();
            _messageRepo.markAsRead(widget.conversation.convId);
          }
        },
        onMessageSentConfirm: (msg) {
          if (msg.convId == widget.conversation.convId) {
            if (!mounted) return;
            setState(() => _upsertMessage(msg, replacePending: true));
            _scrollToBottom();
          }
        },
        onMessagesReadByOther: (convId) {
          if (convId == widget.conversation.convId) {
            if (!mounted) return;
            setState(() {
              for (int i = 0; i < _messages.length; i++) {
                if (_messages[i].senderId == _currentUserId) {
                  _messages[i] = _messages[i].copyWith(isRead: true);
                }
              }
            });
          }
        },
      );

      _messageRepo.markAsRead(widget.conversation.convId);
    } catch (_) {}
  }

  String _cleanError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  bool _isPendingLocalMessage(Message message) {
    return message.senderId == _currentUserId &&
        message.messageId > 900000000000;
  }

  bool _sameMessagePayload(Message a, Message b) {
    return a.convId == b.convId &&
        a.senderId == b.senderId &&
        a.msgType == b.msgType &&
        a.fileUrl == b.fileUrl &&
        a.content == b.content;
  }

  void _upsertMessage(Message msg, {bool replacePending = false}) {
    final existingIndex =
        _messages.indexWhere((message) => message.messageId == msg.messageId);
    if (existingIndex != -1) {
      _messages[existingIndex] = msg;
      return;
    }

    final duplicateIndex =
        _messages.indexWhere((message) => _sameMessagePayload(message, msg));
    if (duplicateIndex != -1) {
      _messages[duplicateIndex] = msg;
      return;
    }

    if (replacePending && msg.senderId == _currentUserId) {
      final pendingIndex = _messages.lastIndexWhere((message) =>
          _isPendingLocalMessage(message) &&
          message.convId == msg.convId &&
          message.msgType == msg.msgType &&
          message.fileUrl == msg.fileUrl);
      if (pendingIndex != -1) {
        _messages[pendingIndex] = msg;
        return;
      }
    }

    _messages.add(msg);
    _messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  void _loadMockMessages() {
    _messages.addAll([
      Message(
        messageId: 1,
        convId: widget.conversation.convId,
        senderId: widget.conversation.otherUserId,
        content:
            'Chào bạn, tôi là ${widget.conversation.otherUserName.split(' (').first}. Bạn đang quan tâm đến tin đăng của tôi đúng không?',
        msgType: 'text',
        isRead: true,
        sentAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Message(
        messageId: 2,
        convId: widget.conversation.convId,
        senderId: _currentUserId,
        content:
            'Dạ vâng đúng rồi ạ, em muốn hỏi phòng này hiện tại còn trống không và giá thuê thực tế có bao gồm phí dịch vụ gì chưa ạ?',
        msgType: 'text',
        isRead: true,
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Message(
        messageId: 3,
        convId: widget.conversation.convId,
        senderId: widget.conversation.otherUserId,
        content:
            'Phòng này vẫn còn trống em nhé. Đây là hình ảnh thực tế của căn phòng:',
        msgType: 'text',
        isRead: true,
        sentAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
      Message(
        messageId: 4,
        convId: widget.conversation.convId,
        senderId: widget.conversation.otherUserId,
        content: 'Hình ảnh phòng chụp sáng nay',
        msgType: 'image',
        fileUrl: widget.conversation.listingImage ??
            'https://images.unsplash.com/photo-1522771739844-6a9f6d5f14af?auto=format&fit=crop&w=600&q=80',
        isRead: true,
        sentAt: DateTime.now().subtract(const Duration(minutes: 44)),
      ),
      if (widget.conversation.lastMessage != null &&
          widget.conversation.convId != 104)
        Message(
          messageId: 5,
          convId: widget.conversation.convId,
          senderId: widget.conversation.otherUserId,
          content: widget.conversation.lastMessage!,
          msgType: 'text',
          isRead: true,
          sentAt: widget.conversation.lastMsgAt ??
              DateTime.now().subtract(const Duration(minutes: 12)),
        ),
    ]);

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scrollToBottom(animated: false));
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollCtrl.hasClients) return;
    if (animated) {
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: AppConstants.animNormal,
        curve: Curves.easeOutQuad,
      );
    } else {
      _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
    }
  }

  void _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isSending) return;

    _textCtrl.clear();
    setState(() => _isSending = true);
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = Message(
      messageId: tempId,
      convId: widget.conversation.convId,
      senderId: _currentUserId,
      content: text,
      msgType: 'text',
      isRead: false,
      sentAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });

    _scrollToBottom();

    try {
      await _messageRepo.sendMessage(
        convId: widget.conversation.convId,
        content: text,
      );
    } catch (e) {
      if (!mounted) return;
      final stillPending =
          _messages.any((message) => message.messageId == tempId);
      if (!stillPending) return;
      setState(() {
        _messages.removeWhere((message) => message.messageId == tempId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('chat_send_error'.tr.replaceAll('{error}', _cleanError(e))),
          action: SnackBarAction(
            label: 'common_retry'.tr,
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _isSending = true;
                _messages.add(tempMessage);
              });
              _scrollToBottom();
              _messageRepo
                  .sendMessage(
                convId: widget.conversation.convId,
                content: text,
              )
                  .catchError((err) {
                if (mounted) {
                  final retryStillPending =
                      _messages.any((message) => message.messageId == tempId);
                  if (!retryStillPending) return;
                  setState(() {
                    _messages
                        .removeWhere((message) => message.messageId == tempId);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('chat_send_retry_failed'
                            .tr
                            .replaceAll('{error}', _cleanError(err)))),
                  );
                }
              }).whenComplete(() {
                if (mounted) setState(() => _isSending = false);
              });
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _sendMediaMessage(String type, String content, String url) async {
    final tempId = DateTime.now().millisecondsSinceEpoch;
    final tempMessage = Message(
      messageId: tempId,
      convId: widget.conversation.convId,
      senderId: _currentUserId,
      content: content,
      msgType: type,
      fileUrl: url,
      isRead: false,
      sentAt: DateTime.now(),
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    try {
      await _messageRepo.sendMessage(
        convId: widget.conversation.convId,
        content: content,
        msgType: type,
        fileUrl: url,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.remove(tempMessage);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('chat_media_send_error'
                .tr
                .replaceAll('{error}', _cleanError(e)))),
      );
    }
  }

  void _confirmRentalAction() async {
    if (!_canConfirmRental || _isListingRented) return;

    final otherUserName = widget.conversation.otherUserName.split(" (").first;
    const title = 'Xác nhận cho thuê';
    final content =
        'Xác nhận rằng bạn đã cho $otherUserName thuê phòng trọ này?';
    const successMessage =
        'Đã xác nhận cho thuê thành công! Người thuê hiện đã có quyền đánh giá phòng trọ này.';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.profileCard,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        title: const Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(content,
            style: TextStyle(color: context.profileTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common_cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ConversationRepository();
      await repo.confirmRental(widget.conversation.convId);
      if (!mounted) return;
      setState(() {
        _isListingRented = true;
        _canConfirmRental = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: ${_cleanError(e)}'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isConnected)
              Container(
                color: Colors.amber.shade700,
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'chat_connecting'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            if (_isListingUnavailable)
              Container(
                decoration: BoxDecoration(
                  color: context.isDarkProfile
                      ? context.profileSubtleCard
                      : Colors.red.shade50.withValues(alpha: 0.9),
                  border: Border(
                    bottom: BorderSide(
                      color: context.isDarkProfile
                          ? Colors.red.withValues(alpha: 0.3)
                          : Colors.red.shade100,
                      width: 1,
                    ),
                  ),
                ),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'chat_listing_unavailable'.tr,
                        style: TextStyle(
                          color: context.isDarkProfile
                              ? Colors.red.shade400
                              : Colors.red.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_showListingHeader && widget.conversation.listingTitle != null)
              _buildListingContextBar(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _errorMessage != null
                      ? _buildErrorBody()
                      : _buildMessagesList(),
            ),
            if (_isTyping) _buildTypingIndicator(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 42, color: context.profileTextMuted),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'chat_error_load_failed'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.profileTextSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRealMessages,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('common_retry'.tr),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final appBarBg =
        context.isDarkProfile ? context.profileCard : AppColors.primary;
    return AppBar(
      backgroundColor: appBarBg,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      leadingWidth: 40,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.only(left: 8),
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
      title: Row(
        children: [
          // User Avatar with green status ring
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  color: context.profileSubtleCard,
                ),
                child: widget.conversation.otherUserAvatar != null
                    ? ClipOval(
                        child: Image.network(
                          widget.conversation.otherUserAvatar!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarPlaceholder(
                              widget.conversation.otherUserName),
                        ),
                      )
                    : _buildAvatarPlaceholder(
                        widget.conversation.otherUserName),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: appBarBg, width: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.conversation.otherUserName.split(' (').first,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'chat_active'.tr,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            _showCallDialog();
          },
          icon: const Icon(Icons.phone_rounded, color: Colors.white),
          tooltip: 'chat_action_call'.tr,
        ),
        IconButton(
          onPressed: () {
            _showMoreOptions();
          },
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          tooltip: 'chat_action_more'.tr,
        ),
      ],
    );
  }

  Widget _buildAvatarPlaceholder(String name) {
    final initials =
        name.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase();
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : 'U',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color:
              context.isDarkProfile ? context.profileText : AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildListingContextBar() {
    final price = _formatListingPrice(_listingPrice);
    final area = _formatListingArea(_listingArea);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: context.profileCard,
        border: Border(
          bottom: BorderSide(color: context.profileBorder),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Listing Thumbnail
          if (widget.conversation.listingImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              child: Image.network(
                widget.conversation.listingImage!,
                width: 50,
                height: 50,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 12),
          // Title + Sub-Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.conversation.listingTitle ??
                      'chat_listing_placeholder'.tr,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.profileText,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      price,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.isDarkProfile
                            ? context.profileSubtleCard
                            : AppColors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: Text(
                        area,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: context.isDarkProfile
                              ? context.profileText
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action Buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if ((_currentUserId == widget.conversation.landlordId ||
                      (_listingLandlordId != null &&
                          _currentUserId == _listingLandlordId)) &&
                  _canConfirmRental &&
                  !_isListingRented) ...[
                GestureDetector(
                  onTap: _confirmRentalAction,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: const Text(
                      'Xác nhận đã thuê',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () {
                  final listingId = widget.conversation.listingId;
                  if (listingId != null && listingId != 0) {
                    context.push('/listing/$listingId');
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Không có thông tin phòng trọ này.')),
                    );
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Text(
                    'chat_view_room'.tr,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showListingHeader = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: context.profileBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: context.profileTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatListingPrice(double? value) {
    if (value == null || value <= 0) return '-- ${'chat_month_suffix'.tr}';
    final millions = value / 1000000;
    final amount = millions == millions.roundToDouble()
        ? millions.toInt().toString()
        : millions.toStringAsFixed(1);
    return '$amount ${'chat_month_suffix'.tr}';
  }

  String _formatListingArea(double? value) {
    if (value == null || value <= 0) return '-- m²';
    final amount = value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
    return '$amount m²';
  }

  Widget _buildMessagesList() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == _currentUserId;

        // Group dates display logic if needed (simplified here)
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final timeStr = _formatBubbleTime(message.sentAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Bubble Content
            Container(
              padding: message.msgType == 'image'
                  ? const EdgeInsets.all(3)
                  : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : context.profileCard,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppConstants.radiusLg),
                  topRight: const Radius.circular(AppConstants.radiusLg),
                  bottomLeft: Radius.circular(
                      isMe ? AppConstants.radiusLg : AppConstants.radiusSm),
                  bottomRight: Radius.circular(
                      isMe ? AppConstants.radiusSm : AppConstants.radiusLg),
                ),
                border: isMe ? null : Border.all(color: context.profileBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildBubbleBody(message, isMe),
            ),
            const SizedBox(height: 4),
            // Timestamp and Read Receipts
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 9,
                    color: context.profileTextMuted,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 12,
                    color: message.isRead
                        ? AppColors.primary
                        : context.profileTextMuted,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleBody(Message message, bool isMe) {
    if (message.msgType == 'image') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusLg - 2),
        child: Image.network(
          message.fileUrl ?? '',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 150,
            height: 150,
            color: context.profileBg,
            child: Icon(Icons.image_not_supported_rounded,
                color: context.profileTextMuted),
          ),
        ),
      );
    } else if (message.msgType == 'file') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_drive_file_rounded,
            color: isMe ? Colors.white : AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isMe ? Colors.white : context.profileText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1.2 MB • PDF',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : context.profileTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Default text message
    return Text(
      message.content,
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w500,
        color: isMe ? Colors.white : context.profileText,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            'chat_typing'.tr.replaceAll('{username}',
                widget.conversation.otherUserName.split(' (').first),
            style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: context.profileTextSecondary),
          ),
          const SizedBox(width: 4),
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
                strokeWidth: 1.5, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    if (_isListingUnavailable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: context.profileSubtleCard,
          border:
              Border(top: BorderSide(color: context.profileBorder, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded,
                color: context.profileTextSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              'chat_listing_closed'.tr,
              style: TextStyle(
                color: context.profileTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.profileCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment Plus Button
          GestureDetector(
            onTap: () {
              _showAttachmentPanel();
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.isDarkProfile
                    ? context.profileSubtleCard
                    : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // TextInput Box
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: context.profileInputFill,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: context.isDarkProfile
                    ? Border.all(color: context.profileBorder)
                    : null,
              ),
              child: TextField(
                controller: _textCtrl,
                onSubmitted: (_) => _sendMessage(),
                onChanged: (val) {
                  // Trigger rebuilding text vs send icon switch
                  setState(() {});
                },
                style: TextStyle(color: context.profileText),
                decoration: InputDecoration(
                  hintText: 'chat_input_hint'.tr,
                  hintStyle:
                      TextStyle(color: context.profileTextMuted, fontSize: 13),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Send Button
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSending
                    ? Icons.hourglass_top_rounded
                    : _textCtrl.text.trim().isEmpty
                        ? Icons.mic_rounded
                        : Icons.send_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.profileCard,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXxl)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.profileBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'chat_attachment_title'.tr,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.profileText),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  label: 'chat_attachment_image'.tr,
                  color: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    // Send mock image
                    _sendMediaMessage(
                      'image',
                      'photo.jpg',
                      'https://images.unsplash.com/photo-1513694203232-719a280e022f?auto=format&fit=crop&w=600&q=80',
                    );
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'chat_attachment_camera'.tr,
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    // Send mock camera photo
                    _sendMediaMessage(
                      'image',
                      'camera_photo.jpg',
                      'https://images.unsplash.com/photo-1484154218962-a197022b5858?auto=format&fit=crop&w=600&q=80',
                    );
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file_rounded,
                  label: 'chat_attachment_document'.tr,
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    // Send mock PDF document
                    _sendMediaMessage(
                      'file',
                      'Hop_Dong_Thue_Phong.pdf',
                      '',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.profileTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String? _getContactPhone() {
    final rawPhone = widget.conversation.otherUserPhone?.trim();
    if (rawPhone == null || rawPhone.isEmpty) return null;

    final normalized = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    return normalized.isEmpty ? null : normalized;
  }

  String _getZaloPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('84') && digits.length > 2) {
      return '0${digits.substring(2)}';
    }
    return digits;
  }

  void _showContactError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openPhoneDialer(String phone) async {
    final phoneUri = Uri(scheme: 'tel', path: phone);

    try {
      final launched = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showContactError('Không mở được ứng dụng Điện thoại.');
      }
    } catch (_) {
      _showContactError('Không mở được ứng dụng Điện thoại.');
    }
  }

  Future<void> _openZalo(String phone) async {
    final zaloPhone = _getZaloPhone(phone);
    if (zaloPhone.isEmpty) {
      _showContactError('Số điện thoại không hợp lệ.');
      return;
    }

    final zaloUri = Uri.https('zalo.me', '/$zaloPhone');

    try {
      final launched = await launchUrl(
        zaloUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        _showContactError(
          'Không tìm thấy Zalo cho số điện thoại này hoặc chưa cài Zalo.',
        );
      }
    } catch (_) {
      _showContactError(
        'Không tìm thấy Zalo cho số điện thoại này hoặc chưa cài Zalo.',
      );
    }
  }

  void _showCallDialog() {
    final phone = _getContactPhone();
    if (phone == null) {
      _showContactError('Người dùng chưa cập nhật số điện thoại.');
      return;
    }

    final displayName =
        widget.conversation.otherUserName.split(' (').first.trim();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: context.profileCard,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXxl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.profileBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                style: TextStyle(
                  color: context.profileText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                phone,
                style: TextStyle(
                  color: context.profileTextSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(Icons.phone_rounded, color: Color(0xFF16A34A)),
                ),
                title: Text(
                  'Gọi bằng điện thoại',
                  style: TextStyle(
                    color: context.profileText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text('Mở ứng dụng Điện thoại với số đã nhập'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openPhoneDialer(phone);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F1FF),
                  child:
                      Icon(Icons.chat_bubble_rounded, color: Color(0xFF0068FF)),
                ),
                title: Text(
                  'Liên hệ qua Zalo',
                  style: TextStyle(
                    color: context.profileText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Zalo sẽ báo nếu số này không có tài khoản',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openZalo(phone);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.profileCard,
          borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXxl)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_isListingUnavailable)
                ListTile(
                  leading: const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary),
                  title: Text(
                    'Đặt lịch xem phòng',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.profileText),
                  ),
                  onTap: () {
                    final listingId = widget.conversation.listingId;
                    Navigator.pop(context);
                    if (listingId != null && listingId != 0) {
                      context.push('/listing/$listingId?openSchedule=true');
                    }
                  },
                ),
              ListTile(
                leading: Icon(Icons.bookmark_border_rounded,
                    color: context.profileText),
                title: Text('chat_option_save_listing'.tr,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: context.profileText)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('chat_option_saved_success'.tr)),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.block_rounded, color: AppColors.error),
                title: Text('chat_option_block'.tr,
                    style: const TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem_outlined,
                    color: AppColors.error),
                title: Text('chat_option_report'.tr,
                    style: const TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  context.push(AppConstants.routeReportIssue);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatBubbleTime(DateTime date) {
    final minuteString =
        date.minute < 10 ? '0${date.minute}' : '${date.minute}';
    return '${date.hour}:$minuteString';
  }
}
