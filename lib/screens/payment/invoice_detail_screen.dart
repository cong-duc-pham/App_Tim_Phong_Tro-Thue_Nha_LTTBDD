import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/payment.dart';

class InvoiceDetailScreen extends StatelessWidget {
  const InvoiceDetailScreen({super.key, required this.invoice});

  final Invoice invoice;

  Future<void> _exportBill(BuildContext context) async {
    try {
      final content = _buildBillContent();
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          '${invoice.invoiceCode.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')}_bill.txt';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(content);
      await Clipboard.setData(ClipboardData(text: content));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Đã xuất bill và sao chép nội dung. File: ${file.path}'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể xuất bill: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _copyBill(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _buildBillContent()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép nội dung bill.'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _buildBillContent() {
    return [
      'SWING HOUSE - BILL THANH TOÁN',
      '--------------------------------',
      'Mã hóa đơn: ${invoice.invoiceCode}',
      'Loại hóa đơn: ${invoice.typeLabel}',
      'Trạng thái: ${invoice.statusLabel}',
      'Số tiền: ${_formatMoney(invoice.totalAmount)}',
      'Ngày tạo: ${_formatDate(invoice.createdAt)}',
      if (invoice.dueDate != null && invoice.dueDate!.trim().isNotEmpty)
        'Hạn thanh toán: ${invoice.dueDate}',
      if (invoice.listingId > 0) 'Mã tin đăng: #${invoice.listingId}',
      if (invoice.note != null && invoice.note!.trim().isNotEmpty)
        'Ghi chú: ${invoice.note!.trim()}',
      '--------------------------------',
      'Cảm ơn bạn đã sử dụng SWING HOUSE.',
    ].join('\n');
  }

  String _formatMoney(double value) {
    final raw = value.toInt().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write('.');
      buffer.write(raw[i]);
    }
    return '$bufferđ';
  }

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    return '${local.day}/${local.month}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = invoice.statusColor;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Chi tiết bill'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.borderLight),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: statusColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SWING HOUSE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            invoice.invoiceCode,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _BillStatus(label: invoice.statusLabel, color: statusColor),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Tổng thanh toán',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatMoney(invoice.totalAmount),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _BillRow(label: 'Loại hóa đơn', value: invoice.typeLabel),
                _BillRow(
                    label: 'Ngày tạo', value: _formatDate(invoice.createdAt)),
                if (invoice.dueDate != null &&
                    invoice.dueDate!.trim().isNotEmpty)
                  _BillRow(label: 'Hạn thanh toán', value: invoice.dueDate!),
                if (invoice.listingId > 0)
                  _BillRow(
                      label: 'Mã tin đăng', value: '#${invoice.listingId}'),
                if (invoice.note != null && invoice.note!.trim().isNotEmpty)
                  _BillRow(label: 'Ghi chú', value: invoice.note!.trim()),
                const Divider(height: 28, color: AppColors.borderLight),
                const Text(
                  'Cảm ơn bạn đã sử dụng SWING HOUSE.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copyBill(context),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Sao chép'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportBill(context),
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text('Xuất file'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (invoice.listingId > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/listing/${invoice.listingId}'),
                icon: const Icon(Icons.home_work_outlined, size: 18),
                label: const Text('Xem tin đăng liên quan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillStatus extends StatelessWidget {
  const _BillStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension InvoiceBillView on Invoice {
  bool get isPending => statusId == 1;
  bool get isSuccess => statusId == 2;

  String get statusLabel {
    if (statusId == 1) return 'Chờ thanh toán';
    if (statusId == 2) return 'Đã thanh toán';
    if (statusId == 3) return 'Thất bại';
    if (statusId == 4) return 'Hoàn tiền';
    return 'Trạng thái #$statusId';
  }

  Color get statusColor {
    if (statusId == 1) return AppColors.warning;
    if (statusId == 2) return AppColors.success;
    if (statusId == 3) return AppColors.error;
    return AppColors.textSecondary;
  }

  String get typeLabel {
    if (invoiceType == 'post_package') return 'Gói đăng tin';
    return invoiceType;
  }
}
