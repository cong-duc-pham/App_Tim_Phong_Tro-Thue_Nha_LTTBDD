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

class Invoice {
  final int invoiceId;
  final int landlordId;
  final int listingId;
  final String invoiceCode;
  final String invoiceType;
  final double totalAmount;
  final String? dueDate;
  final String? note;
  final int statusId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Invoice({
    required this.invoiceId,
    required this.landlordId,
    required this.listingId,
    required this.invoiceCode,
    required this.invoiceType,
    required this.totalAmount,
    required this.dueDate,
    required this.note,
    required this.statusId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
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

    String? text(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      return value?.toString();
    }

    DateTime? dateTime(String camel, String pascal) {
      final value = json[camel] ?? json[pascal];
      if (value == null) return null;
      return DateTime.tryParse(value.toString());
    }

    return Invoice(
      invoiceId: integer('invoiceId', 'InvoiceId'),
      landlordId: integer('landlordId', 'LandlordId'),
      listingId: integer('listingId', 'ListingId'),
      invoiceCode: text('invoiceCode', 'InvoiceCode') ?? '',
      invoiceType: text('invoiceType', 'InvoiceType') ?? '',
      totalAmount: number('totalAmount', 'TotalAmount'),
      dueDate: text('dueDate', 'DueDate'),
      note: text('note', 'Note'),
      statusId: integer('statusId', 'StatusId'),
      createdAt: dateTime('createdAt', 'CreatedAt'),
      updatedAt: dateTime('updatedAt', 'UpdatedAt'),
    );
  }
}
