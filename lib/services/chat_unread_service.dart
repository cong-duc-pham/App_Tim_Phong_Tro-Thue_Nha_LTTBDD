import 'package:flutter/foundation.dart';

import '../models/conversation.dart';
import '../repositories/conversation_repository.dart';

class ChatUnreadService {
  ChatUnreadService._();

  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static Future<void> refresh({ConversationRepository? repository}) async {
    try {
      final conversations =
          await (repository ?? ConversationRepository()).getConversations();
      setFromConversations(conversations);
    } catch (_) {
      unreadCount.value = 0;
    }
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
