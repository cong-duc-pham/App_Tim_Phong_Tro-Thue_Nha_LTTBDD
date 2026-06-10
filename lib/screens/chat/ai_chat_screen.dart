import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/profile_theme.dart';
import '../../models/ai_chat_message.dart';
import '../../repositories/ai_chat_repository.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _suggestions = [
    'Giúp tôi lập tiêu chí tìm phòng phù hợp',
    'Tôi nên hỏi chủ nhà những gì trước khi đặt cọc?',
    'Cách nhận biết tin đăng phòng trọ đáng ngờ?',
  ];

  final _repository = AiChatRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<AiChatMessage> _messages = const [
    AiChatMessage(
      role: 'assistant',
      content:
          'Chào bạn, mình là trợ lý tìm phòng của Swings House. Bạn có thể cho mình biết khu vực, ngân sách và nhu cầu để bắt đầu.',
    ),
  ].toList();

  bool _isSending = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestedText]) async {
    final text = (suggestedText ?? _textController.text).trim();
    if (text.isEmpty || _isSending) return;

    _textController.clear();
    setState(() {
      _messages.add(AiChatMessage(role: 'user', content: text));
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final reply = await _repository.sendMessages(
        _messages.where((message) => message.content.isNotEmpty).toList(),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(AiChatMessage(role: 'assistant', content: reply));
      });
    } catch (error) {
      if (!mounted) return;
      final message =
          error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      appBar: AppBar(
        backgroundColor:
            context.isDarkProfile ? context.profileCard : AppColors.primary,
        foregroundColor: Colors.white,
        titleSpacing: 0,
        title: const Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              child: Icon(Icons.auto_awesome_rounded, color: Colors.white),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trợ lý AI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Hỗ trợ tìm phòng 24/7',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Xóa cuộc trò chuyện',
            onPressed: _isSending
                ? null
                : () {
                    setState(() {
                      _messages
                        ..clear()
                        ..add(const AiChatMessage(
                          role: 'assistant',
                          content:
                              'Cuộc trò chuyện đã được làm mới. Bạn đang muốn tìm phòng ở khu vực nào?',
                        ));
                    });
                  },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length) {
                    return const _TypingBubble();
                  }
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),
            if (_messages.length == 1) _buildSuggestions(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return ActionChip(
            label: Text(_suggestions[index]),
            onPressed: () => _send(_suggestions[index]),
            backgroundColor: context.profileCard,
            side: BorderSide(color: context.profileBorder),
            labelStyle: TextStyle(
              color: context.profileTextSecondary,
              fontSize: 12,
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: context.profileCard,
        border: Border(top: BorderSide(color: context.profileBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_isSending,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              style: TextStyle(color: context.profileText),
              decoration: InputDecoration(
                hintText: 'Nhập câu hỏi về tìm phòng...',
                filled: true,
                fillColor: context.profileInputFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _isSending ? null : _send,
            style: IconButton.styleFrom(backgroundColor: AppColors.primary),
            icon: _isSending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primary : context.profileCard,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border:
              message.isUser ? null : Border.all(color: context.profileBorder),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: message.isUser ? Colors.white : context.profileText,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.profileCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.profileBorder),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
