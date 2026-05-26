// lib/models/message.dart

class Message {
  final int messageId;
  final int convId;
  final int senderId;
  final String content;
  final String msgType; // 'text', 'image', 'file'
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

  /// Factory constructor to parse JSON from .NET API
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      messageId: (json['messageId'] as num?)?.toInt() ?? 0,
      convId: (json['convId'] as num?)?.toInt() ?? 0,
      senderId: (json['senderId'] as num?)?.toInt() ?? 0,
      content: json['content'] as String? ?? '',
      msgType: json['msgType'] as String? ?? 'text',
      fileUrl: json['fileUrl'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      sentAt: json['sentAt'] != null
          ? DateTime.tryParse(json['sentAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Convert model to JSON for API requests
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

  /// Create a copy of the message with modified fields (useful for local state updates)
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
