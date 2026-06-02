// lib/models/post_package.dart

class PostPackage {
  final int packageId;
  final String packageName;
  final String packageType;
  final int durationDays;
  final double price;
  final int priority;
  final int maxImages;
  final int maxVideos;
  final bool allowBanner;
  final String? badgeType;
  final bool hasAnalytics;
  final bool isHighlighted;
  final String? description;
  final bool isActive;

  const PostPackage({
    required this.packageId,
    required this.packageName,
    required this.packageType,
    required this.durationDays,
    required this.price,
    required this.priority,
    required this.maxImages,
    required this.maxVideos,
    required this.allowBanner,
    required this.badgeType,
    required this.hasAnalytics,
    required this.isHighlighted,
    required this.description,
    required this.isActive,
  });

  bool get isFree => price <= 0 || packageType == 'free';
  bool get isFeatured => packageType == 'featured' || isHighlighted;
  bool get isVip => packageType == 'vip';

  factory PostPackage.fromJson(Map<String, dynamic> json) {
    T? read<T>(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value is T ? value : null;
    }

    int integer(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    double number(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is num) return value.toDouble();
      return double.tryParse(value?.toString() ?? '') ?? 0;
    }

    bool boolean(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value is bool) return value;
      if (value is num) return value != 0;
      return value?.toString().toLowerCase() == 'true';
    }

    return PostPackage(
      packageId: integer('packageId', 'PackageId'),
      packageName: read<String>('packageName', 'PackageName') ?? 'Gói đăng tin',
      packageType: read<String>('packageType', 'PackageType') ?? 'free',
      durationDays: integer('durationDays', 'DurationDays'),
      price: number('price', 'Price'),
      priority: integer('priority', 'Priority'),
      maxImages: integer('maxImages', 'MaxImages'),
      maxVideos: integer('maxVideos', 'MaxVideos'),
      allowBanner: boolean('allowBanner', 'AllowBanner'),
      badgeType: read<String>('badgeType', 'BadgeType'),
      hasAnalytics: boolean('hasAnalytics', 'HasAnalytics'),
      isHighlighted: boolean('isHighlighted', 'IsHighlighted'),
      description: read<String>('description', 'Description'),
      isActive: boolean('isActive', 'IsActive'),
    );
  }
}
