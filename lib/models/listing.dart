// lib/models/listing.dart

class Listing {
  final int listingId;
  final String title;
  final String? description;
  final double price;
  final double area;
  final int typeId;
  final String typeName;

  // địa chỉ
  final String? provinceName;
  final String? districtName;
  final String? wardName;
  final String streetAddress;
  final double? latitude;
  final double? longitude;

  // ảnh: image0 là ảnh bìa, image1-5 là gallery
  final String? image0;
  final String? image1;
  final String? image2;
  final String? image3;
  final String? image4;
  final String? image5;

  // thông tin chủ trọ
  final int? landlordId;
  final String? landlordName;
  final String? landlordAvatar;
  final String? landlordPhone;

  // giá điện nước internet xe - null = chưa có thông tin
  final double? electricPrice;
  final double? waterPrice;
  final double? internetPrice;
  final double? parkingPrice;

  // thông tin phòng
  final int? floor;
  final int? totalFloors;
  final int? maxOccupants;
  final bool allowPet;
  final DateTime? availableFrom;

  final bool isVerified;
  final bool isFeatured;
  final String statusName;
  final int? viewCount;
  final int? saveCount;

  // rating trung bình và số lượng đánh giá
  final double averageRating;
  final int reviewCount;

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
    this.latitude,
    this.longitude,
    this.image0,
    this.image1,
    this.image2,
    this.image3,
    this.image4,
    this.image5,
    this.landlordId,
    this.landlordName,
    this.landlordAvatar,
    this.landlordPhone,
    this.electricPrice,
    this.waterPrice,
    this.internetPrice,
    this.parkingPrice,
    this.floor,
    this.totalFloors,
    this.maxOccupants,
    required this.allowPet,
    this.availableFrom,
    required this.isVerified,
    required this.isFeatured,
    required this.statusName,
    this.viewCount,
    this.saveCount,
    this.averageRating = 0,
    this.reviewCount = 0,
    required this.amenityNames,
    this.createdAt,
    this.packageInfo,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    // hỗ trợ cả camelCase lẫn PascalCase vì backend .NET trả về PascalCase
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    double number(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    double? nullableNumber(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int integer(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    int? nullableInt(String camel, String pascal) {
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

    final amenitiesRaw = json['amenityNames'] ?? json['AmenityNames'];
    final packageRaw = json['packageInfo'] ?? json['PackageInfo'];
    final createdRaw = json['createdAt'] ?? json['CreatedAt'];
    final availableRaw = json['availableFrom'] ?? json['AvailableFrom'];

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
      latitude: nullableNumber('latitude', 'Latitude'),
      longitude: nullableNumber('longitude', 'Longitude'),
      image0: read<String>('image0', 'Image0'),
      image1: read<String>('image1', 'Image1'),
      image2: read<String>('image2', 'Image2'),
      image3: read<String>('image3', 'Image3'),
      image4: read<String>('image4', 'Image4'),
      image5: read<String>('image5', 'Image5'),
      landlordId: nullableInt('landlordId', 'LandlordId'),
      landlordName: read<String>('landlordName', 'LandlordName'),
      landlordAvatar: read<String>('landlordAvatar', 'LandlordAvatar'),
      landlordPhone: read<String>('landlordPhone', 'LandlordPhone'),
      electricPrice: nullableNumber('electricPrice', 'ElectricPrice'),
      waterPrice: nullableNumber('waterPrice', 'WaterPrice'),
      internetPrice: nullableNumber('internetPrice', 'InternetPrice'),
      parkingPrice: nullableNumber('parkingPrice', 'ParkingPrice'),
      floor: nullableInt('floor', 'Floor'),
      totalFloors: nullableInt('totalFloors', 'TotalFloors'),
      maxOccupants: nullableInt('maxOccupants', 'MaxOccupants'),
      allowPet: boolean('allowPet', 'AllowPet'),
      availableFrom: availableRaw == null
          ? null
          : DateTime.tryParse(availableRaw.toString()),
      isVerified: boolean('isVerified', 'IsVerified'),
      isFeatured: boolean('isFeatured', 'IsFeatured'),
      statusName: read<String>('statusName', 'StatusName') ?? '',
      viewCount: nullableInt('viewCount', 'ViewCount'),
      saveCount: nullableInt('saveCount', 'SaveCount'),
      averageRating: number('averageRating', 'AverageRating'),
      reviewCount: integer('reviewCount', 'ReviewCount'),
      amenityNames: amenitiesRaw is List
          ? amenitiesRaw.map((e) => e.toString()).toList()
          : const [],
      createdAt:
          createdRaw == null ? null : DateTime.tryParse(createdRaw.toString()),
      packageInfo: packageRaw is Map<String, dynamic> ? packageRaw : null,
    );
  }

  // ghép địa chỉ đầy đủ để hiển thị
  String get displayAddress {
    final parts = [
      if (streetAddress.trim().isNotEmpty) streetAddress.trim(),
      if (wardName?.trim().isNotEmpty == true) wardName!.trim(),
      if (districtName?.trim().isNotEmpty == true) districtName!.trim(),
      if (provinceName?.trim().isNotEmpty == true) provinceName!.trim(),
    ];
    return parts.isEmpty ? 'Chưa cập nhật địa chỉ' : parts.join(', ');
  }

  // lấy tất cả ảnh không null để làm gallery
  List<String> get allImages {
    return [image0, image1, image2, image3, image4, image5]
        .whereType<String>()
        .where((url) => url.trim().isNotEmpty)
        .toList();
  }

  bool get hasLocation => latitude != null && longitude != null;

  Listing copyWith({
    String? title,
    String? description,
    String? typeName,
    String? provinceName,
    String? districtName,
    String? wardName,
    String? streetAddress,
    List<String>? amenityNames,
  }) {
    return Listing(
      listingId: listingId,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price,
      area: area,
      typeId: typeId,
      typeName: typeName ?? this.typeName,
      provinceName: provinceName ?? this.provinceName,
      districtName: districtName ?? this.districtName,
      wardName: wardName ?? this.wardName,
      streetAddress: streetAddress ?? this.streetAddress,
      latitude: latitude,
      longitude: longitude,
      image0: image0,
      image1: image1,
      image2: image2,
      image3: image3,
      image4: image4,
      image5: image5,
      landlordId: landlordId,
      landlordName: landlordName,
      landlordAvatar: landlordAvatar,
      landlordPhone: landlordPhone,
      electricPrice: electricPrice,
      waterPrice: waterPrice,
      internetPrice: internetPrice,
      parkingPrice: parkingPrice,
      floor: floor,
      totalFloors: totalFloors,
      maxOccupants: maxOccupants,
      allowPet: allowPet,
      availableFrom: availableFrom,
      isVerified: isVerified,
      isFeatured: isFeatured,
      statusName: statusName,
      viewCount: viewCount,
      saveCount: saveCount,
      averageRating: averageRating,
      reviewCount: reviewCount,
      amenityNames: amenityNames ?? this.amenityNames,
      createdAt: createdAt,
      packageInfo: packageInfo,
    );
  }
}
