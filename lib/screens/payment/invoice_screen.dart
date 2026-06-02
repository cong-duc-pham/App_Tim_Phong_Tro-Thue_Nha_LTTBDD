import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../models/payment.dart';
import '../../repositories/package_repository.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final PackageRepository _repository = PackageRepository();
  List<Invoice> _invoices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _payingInvoiceCode;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final invoices = await _repository.getMyInvoices();
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _cleanError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _payInvoice(Invoice invoice) async {
    if (!invoice.isPending || _payingInvoiceCode != null) return;

    setState(() => _payingInvoiceCode = invoice.invoiceCode);
    try {
      await _repository.simulateMomoPayment(invoice.invoiceCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanh toán thành công. Gói VIP đã được kích hoạt.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadInvoices();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanError(e)),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _payingInvoiceCode = null);
    }
  }

  String _cleanError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
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
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Hóa đơn & Thanh toán'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeProfile);
            }
          },
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_errorMessage != null) {
      return _StateView(
        icon: Icons.wifi_off_rounded,
        title: 'Không tải được hóa đơn',
        message: _errorMessage!,
        actionLabel: 'Thử lại',
        onAction: _loadInvoices,
      );
    }

    if (_invoices.isEmpty) {
      return _StateView(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có hóa đơn',
        message: 'Các hóa đơn mua gói đăng tin sẽ hiển thị tại đây.',
        actionLabel: 'Xem gói đăng tin',
        onAction: () => context.push(AppConstants.routePackages),
      );
    }

    final paid = _invoices.where((item) => item.isSuccess).length;
    final pending = _invoices.where((item) => item.isPending).length;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadInvoices,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        itemCount: _invoices.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _InvoiceSummary(
              total: _invoices.length,
              paid: paid,
              pending: pending,
            );
          }

          final invoice = _invoices[index - 1];
          return _InvoiceCard(
            invoice: invoice,
            amountLabel: _formatMoney(invoice.totalAmount),
            createdLabel: _formatDate(invoice.createdAt),
            isPaying: _payingInvoiceCode == invoice.invoiceCode,
            onPay: () => _payInvoice(invoice),
            onOpenListing: invoice.listingId > 0
                ? () => context.push('/listing/${invoice.listingId}')
                : null,
          );
        },
      ),
    );
  }
}

class _InvoiceSummary extends StatelessWidget {
  const _InvoiceSummary({
    required this.total,
    required this.paid,
    required this.pending,
  });

  final int total;
  final int paid;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          _SummaryItem(label: 'Tổng', value: '$total', color: AppColors.info),
          _SummaryItem(
            label: 'Đã thanh toán',
            value: '$paid',
            color: AppColors.success,
          ),
          _SummaryItem(
            label: 'Chờ xử lý',
            value: '$pending',
            color: AppColors.warning,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({
    required this.invoice,
    required this.amountLabel,
    required this.createdLabel,
    required this.isPaying,
    required this.onPay,
    this.onOpenListing,
  });

  final Invoice invoice;
  final String amountLabel;
  final String createdLabel;
  final bool isPaying;
  final VoidCallback onPay;
  final VoidCallback? onOpenListing;

  @override
  Widget build(BuildContext context) {
    final color = invoice.statusColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.receipt_long_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      invoice.typeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusBadge(label: invoice.statusLabel, color: color),
            ],
          ),
          const Divider(height: 24, color: AppColors.borderLight),
          _InfoRow(label: 'Số tiền', value: amountLabel, strong: true),
          const SizedBox(height: 8),
          _InfoRow(label: 'Ngày tạo', value: createdLabel),
          if (invoice.note != null && invoice.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(label: 'Ghi chú', value: invoice.note!.trim()),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (onOpenListing != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOpenListing,
                    icon: const Icon(Icons.home_work_outlined, size: 18),
                    label: const Text('Xem tin'),
                  ),
                ),
              if (onOpenListing != null && invoice.isPending)
                const SizedBox(width: 10),
              if (invoice.isPending)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isPaying ? null : onPay,
                    icon: isPaying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.payments_outlined, size: 18),
                    label: Text(isPaying ? 'Đang xử lý' : 'Thanh toán'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: strong ? 14 : 12.5,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: strong ? AppColors.textPrimary : AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

extension _InvoiceView on Invoice {
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
