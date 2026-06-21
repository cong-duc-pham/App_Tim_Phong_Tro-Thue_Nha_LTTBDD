import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import '../models/conversation.dart';
import '../repositories/conversation_repository.dart';
import '../repositories/message_repository.dart';

class ChatUnreadService {
  ChatUnreadService._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  static final MessageRepository _messageRepository = MessageRepository();
  static bool _isStartingRealtime = false;
  static bool _isRealtimeConnected = false;

  static Future<void> start() async {
    await refresh();
    await startRealtime();
  }

  static Future<void> refresh({ConversationRepository? repository}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) {
      unreadCount.value = 0;
      return;
    }

    try {
      final conversations =
          await (repository ?? ConversationRepository()).getConversations();
      setFromConversations(conversations);
    } catch (_) {
      // Giữ số hiện tại khi mạng lỗi tạm thời.
    }
  }

  static Future<void> startRealtime() async {
    if (_isStartingRealtime || _isRealtimeConnected) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConstants.keyUserToken);
    if (token == null || token.isEmpty) return;

    _isStartingRealtime = true;
    try {
      await _messageRepository.connectToChatHub(
        onMessageReceived: (_) {
          unreadCount.value += 1;
        },
        onMessageSentConfirm: (_) {},
        onMessagesReadByOther: (_) {},
        onConnectionStateChanged: (connected) {
          _isRealtimeConnected = connected;
          if (connected) {
            unawaited(refresh());
          }
        },
      );
    } finally {
      _isStartingRealtime = false;
    }
  }

  static Future<void> stopRealtime() async {
    _isStartingRealtime = false;
    _isRealtimeConnected = false;
    await _messageRepository.disconnectFromChatHub();
  }

  static Future<void> stopAndClear() async {
    await stopRealtime();
    unreadCount.value = 0;
  }

  static void setFromConversations(List<Conversation> conversations) {
    unreadCount.value = conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  static void markConversationRead(Conversation conversation) {
    if (conversation.unreadCount <= 0) return;
    final nextValue = unreadCount.value - conversation.unreadCount;
    unreadCount.value = nextValue < 0 ? 0 : nextValue;
  }
}
