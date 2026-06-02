// lib/models/payment.dart

class Payment {
  final int id;
  final int invoiceId;
  final String transactionRef;
  final String paymentGateway; // momo | vnpay
  final double amount;
  final String status; // Pending | Success | Failed
  final DateTime createdAt;
  final DateTime? completedAt;

  Payment({
    required this.id,
    required this.invoiceId,
    required this.transactionRef,
    required this.paymentGateway,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.completedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      invoiceId: json['invoiceId'] is int ? json['invoiceId'] : int.tryParse(json['invoiceId']?.toString() ?? '') ?? 0,
      transactionRef: json['transactionRef'] ?? json['TransactionRef'] ?? '',
      paymentGateway: json['paymentGateway'] ?? json['PaymentGateway'] ?? 'momo',
      amount: (json['amount'] ?? json['Amount'] ?? 0.0) is int
          ? (json['amount'] ?? json['Amount'] ?? 0).toDouble()
          : (json['amount'] ?? json['Amount'] ?? 0.0).toDouble(),
      status: json['status'] ?? json['Status'] ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : (json['CreatedAt'] != null
              ? DateTime.parse(json['CreatedAt'])
              : DateTime.now()),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : (json['CompletedAt'] != null
              ? DateTime.parse(json['CompletedAt'])
              : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoiceId': invoiceId,
      'transactionRef': transactionRef,
      'paymentGateway': paymentGateway,
      'amount': amount,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }
}
