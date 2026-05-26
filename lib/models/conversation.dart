// lib/models/conversation.dart

class Conversation {
  final int convId;
  final int? listingId;
  final String? listingTitle;
  final String? listingImage;
  final String? lastMessage;
  final DateTime? lastMsgAt;
  final int otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final int unreadCount;

  const Conversation({
    required this.convId,
    this.listingId,
    this.listingTitle,
    this.listingImage,
    this.lastMessage,
    this.lastMsgAt,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.unreadCount = 0,
  });

  /// Factory constructor to parse JSON from .NET API
  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      convId: (json['convId'] as num?)?.toInt() ?? 0,
      listingId: (json['listingId'] as num?)?.toInt(),
      listingTitle: json['listingTitle'] as String?,
      listingImage: json['listingImage'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMsgAt: json['lastMsgAt'] != null
          ? DateTime.tryParse(json['lastMsgAt'].toString())
          : null,
      otherUserId: (json['otherUserId'] as num?)?.toInt() ?? 0,
      otherUserName: json['otherUserName'] as String? ?? 'Người dùng',
      otherUserAvatar: json['otherUserAvatar'] as String?,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }

  /// Convert model to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'convId': convId,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingImage': listingImage,
      'lastMessage': lastMessage,
      'lastMsgAt': lastMsgAt?.toIso8601String(),
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserAvatar': otherUserAvatar,
      'unreadCount': unreadCount,
    };
  }

  /// Create a copy of the conversation with modified fields
  Conversation copyWith({
    int? convId,
    int? listingId,
    String? listingTitle,
    String? listingImage,
    String? lastMessage,
    DateTime? lastMsgAt,
    int? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    int? unreadCount,
  }) {
    return Conversation(
      convId: convId ?? this.convId,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImage: listingImage ?? this.listingImage,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMsgAt: lastMsgAt ?? this.lastMsgAt,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
