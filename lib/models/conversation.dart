import '../core/utils/url_helper.dart';

class Conversation {
  final int convId;
  final int? listingId;
  final String? listingTitle;
  final String? listingImage;
  final String? listingStatusName;
  final bool? canConfirmRental;
  final String? lastMessage;
  final DateTime? lastMsgAt;
  final int otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String? otherUserPhone;
  final int unreadCount;
  final int tenantId;
  final int landlordId;

  const Conversation({
    required this.convId,
    this.listingId,
    this.listingTitle,
    this.listingImage,
    this.listingStatusName,
    this.canConfirmRental,
    this.lastMessage,
    this.lastMsgAt,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.otherUserPhone,
    this.unreadCount = 0,
    required this.tenantId,
    required this.landlordId,
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
      listingImage:
          UrlHelper.sanitizeUrl(read<String>('listingImage', 'ListingImage')),
      listingStatusName: read<String>('listingStatusName', 'ListingStatusName'),
      canConfirmRental: read<bool>('canConfirmRental', 'CanConfirmRental'),
      lastMessage: read<String>('lastMessage', 'LastMessage'),
      lastMsgAt: lastMsgAtRaw == null
          ? null
          : DateTime.tryParse(lastMsgAtRaw.toString()),
      otherUserId: integer('otherUserId', 'OtherUserId'),
      otherUserName:
          read<String>('otherUserName', 'OtherUserName') ?? 'Người dùng',
      otherUserAvatar: UrlHelper.sanitizeUrl(
          read<String>('otherUserAvatar', 'OtherUserAvatar')),
      otherUserPhone: read<String>('otherUserPhone', 'OtherUserPhone'),
      unreadCount: integer('unreadCount', 'UnreadCount'),
      tenantId: integer('tenantId', 'TenantId'),
      landlordId: integer('landlordId', 'LandlordId'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'convId': convId,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingImage': listingImage,
      'listingStatusName': listingStatusName,
      'canConfirmRental': canConfirmRental,
      'lastMessage': lastMessage,
      'lastMsgAt': lastMsgAt?.toIso8601String(),
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'otherUserAvatar': otherUserAvatar,
      'otherUserPhone': otherUserPhone,
      'unreadCount': unreadCount,
      'tenantId': tenantId,
      'landlordId': landlordId,
    };
  }

  Conversation copyWith({
    int? convId,
    int? listingId,
    String? listingTitle,
    String? listingImage,
    String? listingStatusName,
    bool? canConfirmRental,
    String? lastMessage,
    DateTime? lastMsgAt,
    int? otherUserId,
    String? otherUserName,
    String? otherUserAvatar,
    String? otherUserPhone,
    int? unreadCount,
    int? tenantId,
    int? landlordId,
  }) {
    return Conversation(
      convId: convId ?? this.convId,
      listingId: listingId ?? this.listingId,
      listingTitle: listingTitle ?? this.listingTitle,
      listingImage: listingImage ?? this.listingImage,
      listingStatusName: listingStatusName ?? this.listingStatusName,
      canConfirmRental: canConfirmRental ?? this.canConfirmRental,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMsgAt: lastMsgAt ?? this.lastMsgAt,
      otherUserId: otherUserId ?? this.otherUserId,
      otherUserName: otherUserName ?? this.otherUserName,
      otherUserAvatar: otherUserAvatar ?? this.otherUserAvatar,
      otherUserPhone: otherUserPhone ?? this.otherUserPhone,
      unreadCount: unreadCount ?? this.unreadCount,
      tenantId: tenantId ?? this.tenantId,
      landlordId: landlordId ?? this.landlordId,
    );
  }
}
