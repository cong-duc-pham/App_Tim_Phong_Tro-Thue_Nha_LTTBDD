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
