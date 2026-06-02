// lib/models/post_package.dart

class PostPackage {
  final int id;
  final String name;
  final String code;
  final double price;
  final int durationDays;
  final String description;
  final int priority;

  PostPackage({
    required this.id,
    required this.name,
    required this.code,
    required this.price,
    required this.durationDays,
    required this.description,
    required this.priority,
  });

  factory PostPackage.fromJson(Map<String, dynamic> json) {
    return PostPackage(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? json['Name'] ?? '',
      code: json['code'] ?? json['Code'] ?? '',
      price: (json['price'] ?? json['Price'] ?? 0.0) is int
          ? (json['price'] ?? json['Price'] ?? 0).toDouble()
          : (json['price'] ?? json['Price'] ?? 0.0).toDouble(),
      durationDays: json['durationDays'] ?? json['DurationDays'] ?? 0,
      description: json['description'] ?? json['Description'] ?? '',
      priority: json['priority'] ?? json['Priority'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'price': price,
      'durationDays': durationDays,
      'description': description,
      'priority': priority,
    };
  }
}
