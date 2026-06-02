// lib/screens/chat/chat_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../repositories/message_repository.dart';
import '../../services/chat_unread_service.dart';

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
  bool _isTyping = false;
  bool _isSending = false;
  String? _errorMessage;
  bool _showListingHeader = true;
  int _currentUserId = 999; // Lấy từ SharedPreferences hoặc fallback 999
  bool _isConnected = true;
  bool _isLoading = true;
  final _messageRepo = MessageRepository();

  bool get _isListingUnavailable => widget.conversation.listingId == null || widget.conversation.listingId == 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId().then((_) {
      _loadRealMessages();
      _setupRealTimeChat();
    });
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
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
            setState(() {
              if (!_messages.any((m) => m.messageId == msg.messageId)) {
                _messages.add(msg);
              }
            });
            _scrollToBottom();
            _messageRepo.markAsRead(widget.conversation.convId);
          }
        },
        onMessageSentConfirm: (msg) {
          if (msg.convId == widget.conversation.convId) {
            if (!mounted) return;
            setState(() {
              final index = _messages.indexWhere((m) => 
                m.messageId == msg.messageId || 
                (m.senderId == _currentUserId && m.content == msg.content && m.messageId > 900000000000)
              );
              if (index != -1) {
                _messages[index] = msg;
              } else {
                _messages.add(msg);
              }
            });
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
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
      setState(() {
        _messages.remove(tempMessage);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể gửi tin nhắn: ${_cleanError(e)}'),
          action: SnackBarAction(
            label: 'Thử lại',
            textColor: Colors.white,
            onPressed: () {
              setState(() {
                _messages.add(tempMessage);
              });
              _scrollToBottom();
              _messageRepo.sendMessage(
                convId: widget.conversation.convId,
                content: text,
              ).catchError((err) {
                if (mounted) {
                  setState(() {
                    _messages.remove(tempMessage);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Thử lại thất bại: ${_cleanError(err)}')),
                  );
                }
              });
            },
          ),
        ),
      );
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
        SnackBar(content: Text('Lỗi gửi phương tiện: ${_cleanError(e)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            if (!_isConnected)
              Container(
                color: Colors.amber.shade700,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Đang kết nối lại...',
                      style: TextStyle(
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
                  color: Colors.red.shade50.withValues(alpha: 0.9),
                  border: Border(
                    bottom: BorderSide(color: Colors.red.shade100, width: 1),
                  ),
                ),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Tin đăng này không còn khả dụng hoặc đã bị xóa.',
                        style: TextStyle(
                          color: Colors.red.shade800,
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
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
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
            const Icon(Icons.wifi_off_rounded, size: 42, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Lỗi kết nối máy chủ',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadRealMessages,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
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
                  color: AppColors.bgCardLight,
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
                  border: Border.all(color: AppColors.primary, width: 1.5),
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
                const Text(
                  'Đang hoạt động',
                  style: TextStyle(
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
          tooltip: 'Gọi điện',
        ),
        IconButton(
          onPressed: () {
            _showMoreOptions();
          },
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          tooltip: 'Tùy chọn khác',
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
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildListingContextBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
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
                  widget.conversation.listingTitle ?? 'Tin đăng phòng trọ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      '4.5 Tr/tháng',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusSm),
                      ),
                      child: const Text(
                        '25 m²',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
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
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Đang chuyển hướng tới chi tiết tin đăng...')),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: const Text(
                    'Xem phòng',
                    style: TextStyle(
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
                  decoration: const BoxDecoration(
                    color: AppColors.bgPage,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppConstants.radiusLg),
                  topRight: const Radius.circular(AppConstants.radiusLg),
                  bottomLeft: Radius.circular(
                      isMe ? AppConstants.radiusLg : AppConstants.radiusSm),
                  bottomRight: Radius.circular(
                      isMe ? AppConstants.radiusSm : AppConstants.radiusLg),
                ),
                border: isMe ? null : Border.all(color: AppColors.borderLight),
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
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textMuted,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all_rounded,
                    size: 12,
                    color: message.isRead
                        ? AppColors.primary
                        : AppColors.textMuted,
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
            color: AppColors.bgPage,
            child: const Icon(Icons.image_not_supported_rounded,
                color: AppColors.textMuted),
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
                    color: isMe ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '1.2 MB • PDF',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : AppColors.textSecondary,
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
        color: isMe ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Text(
            '${widget.conversation.otherUserName.split(' (').first} đang nhập',
            style: const TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary),
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
          color: Colors.grey.shade100,
          border: Border(top: BorderSide(color: Colors.grey.shade300, width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, color: Colors.grey.shade600, size: 20),
            const SizedBox(width: 8),
            Text(
              'Tin đăng đã bị đóng. Bạn không thể gửi tin nhắn.',
              style: TextStyle(
                color: Colors.grey.shade600,
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
        color: Colors.white,
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
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
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
                color: AppColors.bgPage,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              child: TextField(
                controller: _textCtrl,
                onSubmitted: (_) => _sendMessage(),
                onChanged: (val) {
                  // Trigger rebuilding text vs send icon switch
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle:
                      TextStyle(color: AppColors.textMuted, fontSize: 13),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
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
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Gửi phương tiện đính kèm',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.image_rounded,
                  label: 'Hình ảnh',
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
                  label: 'Máy ảnh',
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
                  label: 'Tài liệu',
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
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showCallDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg)),
        title: const Text('Gọi cho chủ nhà?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Bạn có muốn thực hiện cuộc gọi trực tiếp đến ${widget.conversation.otherUserName.split(' (').first} không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Đang khởi tạo cuộc gọi thoại...')),
              );
            },
            child: const Text('Gọi ngay'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXxl)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.bookmark_border_rounded,
                    color: AppColors.textPrimary),
                title: const Text('Lưu tin đăng này',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content:
                            Text('Đã lưu tin đăng vào danh sách yêu thích!')),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.block_rounded, color: AppColors.error),
                title: const Text('Chặn người dùng này',
                    style: TextStyle(
                        color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.report_problem_outlined,
                    color: AppColors.error),
                title: const Text('Báo cáo người dùng',
                    style: TextStyle(
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
