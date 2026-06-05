import '../core/utils/url_helper.dart';

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

  factory Conversation.fromJson(Map<String, dynamic> json) {
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    int integer(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? optionalInteger(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value == null) return null;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    final lastMsgAtRaw = json['lastMsgAt'] ?? json['LastMsgAt'];

    return Conversation(
      convId: integer('convId', 'ConvId'),
      listingId: optionalInteger('listingId', 'ListingId'),
      listingTitle: read<String>('listingTitle', 'ListingTitle'),
      listingImage: UrlHelper.sanitizeUrl(read<String>('listingImage', 'ListingImage')),
      lastMessage: read<String>('lastMessage', 'LastMessage'),
      lastMsgAt: lastMsgAtRaw == null
          ? null
          : DateTime.tryParse(lastMsgAtRaw.toString()),
      otherUserId: integer('otherUserId', 'OtherUserId'),
      otherUserName:
          read<String>('otherUserName', 'OtherUserName') ?? 'Người dùng',
      otherUserAvatar: UrlHelper.sanitizeUrl(read<String>('otherUserAvatar', 'OtherUserAvatar')),
      unreadCount: integer('unreadCount', 'UnreadCount'),
    );
  }

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
