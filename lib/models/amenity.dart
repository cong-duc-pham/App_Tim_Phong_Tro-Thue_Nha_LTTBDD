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
      name: json['name'] ?? json['Name'] ?? '',
      iconUrl: json['iconUrl'] ?? json['IconUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amenityId': amenityId,
      'name': name,
      'iconUrl': iconUrl,
    };
  }
}
