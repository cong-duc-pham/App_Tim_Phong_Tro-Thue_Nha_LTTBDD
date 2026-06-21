class ViewingAppointment {
  final int appointmentId;
  final int listingId;
  final String listingTitle;
  final String? listingImage;
  final String? listingAddress;
  final int tenantId;
  final String tenantName;
  final String? tenantPhone;
  final int landlordId;
  final String landlordName;
  final String? landlordPhone;
  final DateTime scheduledAt;
  final String status;
  final String? tenantNote;
  final String? landlordNote;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool canConfirm;
  final bool canDecline;
  final bool canCancel;

  const ViewingAppointment({
    required this.appointmentId,
    required this.listingId,
    required this.listingTitle,
    this.listingImage,
    this.listingAddress,
    required this.tenantId,
    required this.tenantName,
    this.tenantPhone,
    required this.landlordId,
    required this.landlordName,
    this.landlordPhone,
    required this.scheduledAt,
    required this.status,
    this.tenantNote,
    this.landlordNote,
    this.createdAt,
    this.updatedAt,
    required this.canConfirm,
    required this.canDecline,
    required this.canCancel,
  });

  factory ViewingAppointment.fromJson(Map<String, dynamic> json) {
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    int intValue(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    bool boolValue(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is bool) return value;
      if (value is num) return value != 0;
      return value?.toString().toLowerCase() == 'true';
    }

    DateTime? dateValue(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value == null ? null : DateTime.tryParse(value.toString());
    }

    return ViewingAppointment(
      appointmentId: intValue('appointmentId', 'AppointmentId'),
      listingId: intValue('listingId', 'ListingId'),
      listingTitle: read<String>('listingTitle', 'ListingTitle') ?? 'Phòng trọ',
      listingImage: read<String>('listingImage', 'ListingImage'),
      listingAddress: read<String>('listingAddress', 'ListingAddress'),
      tenantId: intValue('tenantId', 'TenantId'),
      tenantName: read<String>('tenantName', 'TenantName') ?? 'Người thuê',
      tenantPhone: read<String>('tenantPhone', 'TenantPhone'),
      landlordId: intValue('landlordId', 'LandlordId'),
      landlordName: read<String>('landlordName', 'LandlordName') ?? 'Chủ trọ',
      landlordPhone: read<String>('landlordPhone', 'LandlordPhone'),
      scheduledAt:
          dateValue('scheduledAt', 'ScheduledAt')?.toLocal() ?? DateTime.now(),
      status: read<String>('status', 'Status') ?? 'pending',
      tenantNote: read<String>('tenantNote', 'TenantNote'),
      landlordNote: read<String>('landlordNote', 'LandlordNote'),
      createdAt: dateValue('createdAt', 'CreatedAt')?.toLocal(),
      updatedAt: dateValue('updatedAt', 'UpdatedAt')?.toLocal(),
      canConfirm: boolValue('canConfirm', 'CanConfirm'),
      canDecline: boolValue('canDecline', 'CanDecline'),
      canCancel: boolValue('canCancel', 'CanCancel'),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'Đã xác nhận';
      case 'declined':
        return 'Từ chối';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return 'Đang chờ';
    }
  }
}
