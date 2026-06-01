class AppNotification {
  final int id;
  final int userId;
  final String title;
  final String body;
  final String type;
  final int? refId;
  final String? refType;
  final bool isRead;
  final DateTime? sentAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.refId,
    this.refType,
    required this.isRead,
    this.sentAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
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

    bool boolean(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is bool) return value;
      return value?.toString().toLowerCase() == 'true';
    }

    final sentAtRaw = json['sentAt'] ?? json['SentAt'];

    return AppNotification(
      id: integer('notifId', 'NotifId'),
      userId: integer('userId', 'UserId'),
      title: read<String>('title', 'Title') ?? 'Thông báo',
      body: read<String>('body', 'Body') ?? '',
      type: read<String>('notifType', 'NotifType') ?? 'system',
      refId: optionalInteger('refId', 'RefId'),
      refType: read<String>('refType', 'RefType'),
      isRead: boolean('isRead', 'IsRead'),
      sentAt:
          sentAtRaw == null ? null : DateTime.tryParse(sentAtRaw.toString()),
    );
  }
}
