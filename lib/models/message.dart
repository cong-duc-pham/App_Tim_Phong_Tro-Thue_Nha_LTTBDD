import 'dart:convert';

import '../core/utils/url_helper.dart';

class Message {
  final int messageId;
  final int convId;
  final int senderId;
  final String content;
  final String msgType;
  final String? fileUrl;
  final bool isRead;
  final DateTime sentAt;

  const Message({
    required this.messageId,
    required this.convId,
    required this.senderId,
    required this.content,
    this.msgType = 'text',
    this.fileUrl,
    this.isRead = false,
    required this.sentAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    int integer(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    bool boolean(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is bool) return value;
      return value?.toString().toLowerCase() == 'true';
    }

    final sentAtRaw = json['sentAt'] ?? json['SentAt'];

    return Message(
      messageId: integer('messageId', 'MessageId'),
      convId: integer('convId', 'ConvId'),
      senderId: integer('senderId', 'SenderId'),
      content: _repairMojibake(read<String>('content', 'Content') ?? ''),
      msgType: read<String>('msgType', 'MsgType') ?? 'text',
      fileUrl: UrlHelper.sanitizeUrl(read<String>('fileUrl', 'FileUrl')),
      isRead: boolean('isRead', 'IsRead'),
      sentAt: sentAtRaw == null
          ? DateTime.now()
          : DateTime.tryParse(sentAtRaw.toString()) ?? DateTime.now(),
    );
  }

  static String _repairMojibake(String value) {
    if (value.isEmpty) return value;
    final looksBroken = value.contains('Ã') ||
        value.contains('Ä') ||
        value.contains('Æ') ||
        value.contains('áº') ||
        value.contains('á»') ||
        value.contains('Â');
    if (!looksBroken) return value;

    try {
      final repaired = utf8.decode(latin1.encode(value));
      return repaired.contains('�') ? value : repaired;
    } catch (_) {
      return value;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'convId': convId,
      'senderId': senderId,
      'content': content,
      'msgType': msgType,
      'fileUrl': fileUrl,
      'isRead': isRead,
      'sentAt': sentAt.toIso8601String(),
    };
  }

  Message copyWith({
    int? messageId,
    int? convId,
    int? senderId,
    String? content,
    String? msgType,
    String? fileUrl,
    bool? isRead,
    DateTime? sentAt,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      convId: convId ?? this.convId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      msgType: msgType ?? this.msgType,
      fileUrl: fileUrl ?? this.fileUrl,
      isRead: isRead ?? this.isRead,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}
