// lib/models/amenity.dart

class Amenity {
  final int amenityId;
  final String name;
  final String? iconUrl;

  Amenity({
    required this.amenityId,
    required this.name,
    this.iconUrl,
  });

  factory Amenity.fromJson(Map<String, dynamic> json) {
    return Amenity(
      amenityId: json['amenityId'] ?? json['AmenityId'] ?? 0,
      name: displayName(json['name'] ?? json['Name'] ?? ''),
      iconUrl: json['iconUrl'] ?? json['IconUrl'],
    );
  }

  static String displayName(Object? value) {
    final raw = value?.toString().trim() ?? '';
    switch (raw.toLowerCase()) {
      case 'dieu hoa':
        return 'Điều hòa';
      case 'may giat':
        return 'Máy giặt';
      case 'tu lanh':
        return 'Tủ lạnh';
      case 'bep':
        return 'Bếp';
      case 'bai xe':
      case 'gui xe':
        return 'Bãi xe';
      case 'camera an ninh':
        return 'Camera an ninh';
      case 'thang may':
        return 'Thang máy';
      case 'ho boi':
        return 'Hồ bơi';
      case 'ban cong':
        return 'Ban công';
      case 'noi that day du':
        return 'Nội thất đầy đủ';
      case 'cua tu':
        return 'Cửa từ';
      case 'bao ve 24/7':
        return 'Bảo vệ 24/7';
      case 'cho nuoi thu cung':
        return 'Cho nuôi thú cưng';
      default:
        return raw;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'amenityId': amenityId,
      'name': name,
      'iconUrl': iconUrl,
    };
  }
}
