// lib/models/invoice.dart

class Invoice {
  final int id;
  final String userId;
  final String listingId;
  final String packageId;
  final String? packageName;
  final double amount;
  final String paymentStatus; // Pending | Paid | Cancelled
  final String? paymentMethod;
  final String? paymentUrl;
  final DateTime createdAt;
  final DateTime? paidAt;

  Invoice({
    required this.id,
    required this.userId,
    required this.listingId,
    required this.packageId,
    this.packageName,
    required this.amount,
    required this.paymentStatus,
    this.paymentMethod,
    this.paymentUrl,
    required this.createdAt,
    this.paidAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    return Invoice(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      userId: json['userId']?.toString() ?? json['UserId']?.toString() ?? '',
      listingId: json['listingId']?.toString() ?? json['ListingId']?.toString() ?? '',
      packageId: json['packageId']?.toString() ?? json['PackageId']?.toString() ?? '',
      packageName: json['packageName'] ?? json['PackageName'],
      amount: (json['amount'] ?? json['Amount'] ?? 0.0) is int
          ? (json['amount'] ?? json['Amount'] ?? 0).toDouble()
          : (json['amount'] ?? json['Amount'] ?? 0.0).toDouble(),
      paymentStatus: json['paymentStatus'] ?? json['PaymentStatus'] ?? 'Pending',
      paymentMethod: json['paymentMethod'] ?? json['PaymentMethod'],
      paymentUrl: json['paymentUrl'] ?? json['PaymentUrl'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['CreatedAt'] != null
              ? DateTime.parse(json['CreatedAt'])
              : DateTime.now()),
      paidAt: json['paidAt'] != null
          ? DateTime.parse(json['paidAt'])
          : (json['PaidAt'] != null
              ? DateTime.parse(json['PaidAt'])
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'listingId': listingId,
      'packageId': packageId,
      'packageName': packageName,
      'amount': amount,
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      'paymentUrl': paymentUrl,
      'createdAt': createdAt.toIso8601String(),
      'paidAt': paidAt?.toIso8601String(),
    };
  }
}
