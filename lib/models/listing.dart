class Listing {
  final int listingId;
  final String title;
  final String? description;
  final double price;
  final double area;
  final int typeId;
  final String typeName;
  final String? provinceName;
  final String? districtName;
  final String? wardName;
  final String streetAddress;
  final String? image0;
  final bool isVerified;
  final bool isFeatured;
  final bool allowPet;
  final String statusName;
  final List<String> amenityNames;
  final DateTime? createdAt;
  final Map<String, dynamic>? packageInfo;

  const Listing({
    required this.listingId,
    required this.title,
    this.description,
    required this.price,
    required this.area,
    required this.typeId,
    required this.typeName,
    this.provinceName,
    this.districtName,
    this.wardName,
    required this.streetAddress,
    this.image0,
    required this.isVerified,
    required this.isFeatured,
    required this.allowPet,
    required this.statusName,
    required this.amenityNames,
    this.createdAt,
    this.packageInfo,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    double number(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
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

    final amenitiesRaw = json['amenityNames'] ?? json['AmenityNames'];
    final packageRaw = json['packageInfo'] ?? json['PackageInfo'];
    final createdRaw = json['createdAt'] ?? json['CreatedAt'];

    return Listing(
      listingId: integer('listingId', 'ListingId'),
      title: read<String>('title', 'Title') ?? '',
      description: read<String>('description', 'Description'),
      price: number('price', 'Price'),
      area: number('area', 'Area'),
      typeId: integer('typeId', 'TypeId'),
      typeName: read<String>('typeName', 'TypeName') ?? '',
      provinceName: read<String>('provinceName', 'ProvinceName'),
      districtName: read<String>('districtName', 'DistrictName'),
      wardName: read<String>('wardName', 'WardName'),
      streetAddress: read<String>('streetAddress', 'StreetAddress') ?? '',
      image0: read<String>('image0', 'Image0'),
      isVerified: boolean('isVerified', 'IsVerified'),
      isFeatured: boolean('isFeatured', 'IsFeatured'),
      allowPet: boolean('allowPet', 'AllowPet'),
      statusName: read<String>('statusName', 'StatusName') ?? '',
      amenityNames: amenitiesRaw is List
          ? amenitiesRaw.map((e) => e.toString()).toList()
          : const [],
      createdAt: createdRaw == null ? null : DateTime.tryParse(createdRaw.toString()),
      packageInfo: packageRaw is Map<String, dynamic> ? packageRaw : null,
    );
  }

  String get displayAddress {
    final parts = [
      if (streetAddress.trim().isNotEmpty) streetAddress.trim(),
      if (wardName?.trim().isNotEmpty == true) wardName!.trim(),
      if (districtName?.trim().isNotEmpty == true) districtName!.trim(),
      if (provinceName?.trim().isNotEmpty == true) provinceName!.trim(),
    ];
    return parts.isEmpty ? 'Chưa cập nhật địa chỉ' : parts.join(', ');
  }
}
