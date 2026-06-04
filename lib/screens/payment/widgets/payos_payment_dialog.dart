import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/profile_theme.dart';
import '../../../models/payment.dart';
import '../../../repositories/package_repository.dart';
import 'payos_qr_card.dart';

enum PayOsPaymentDialogResult {
  paid,
  payLater,
  openCheckout,
}

class PayOsPaymentDialog extends StatefulWidget {
  const PayOsPaymentDialog({
    super.key,
    required this.invoice,
    required this.packageName,
    required this.amountLabel,
    required this.repository,
  });

  final Invoice invoice;
  final String packageName;
  final String amountLabel;
  final PackageRepository repository;

  @override
  State<PayOsPaymentDialog> createState() => _PayOsPaymentDialogState();
}

class _PayOsPaymentDialogState extends State<PayOsPaymentDialog> {
  Timer? _timer;
  bool _isChecking = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _syncStatus());
    Future.delayed(const Duration(seconds: 2), _syncStatus);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _syncStatus() async {
    if (_isChecking || !mounted) return;

    setState(() {
      _isChecking = true;
      _lastError = null;
    });

    try {
      final invoice =
          await widget.repository.syncPayOsInvoice(widget.invoice.invoiceCode);
      if (!mounted) return;
      if (_isPaid(invoice)) {
        _timer?.cancel();
        Navigator.of(context).pop(PayOsPaymentDialogResult.paid);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      if (e is PayOsSyncUnavailableException) {
        _lastError = null;
      } else {
        _lastError = 'invoice_sync_payment_failed'.tr;
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  bool _isPaid(Invoice invoice) {
    final status = invoice.paymentStatus?.toLowerCase().trim();
    return invoice.statusId == 2 || status == 'success' || status == 'paid';
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth =
        (MediaQuery.sizeOf(context).width - 80).clamp(280.0, 360.0);

    return AlertDialog(
      title: Text('invoice_dialog_created_title'.tr),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'invoice_dialog_success_desc'
                    .tr
                    .replaceAll('{package}', widget.packageName),
                style: TextStyle(color: context.profileTextSecondary),
              ),
              const SizedBox(height: 14),
              PayOsQrCard(
                qrCode: widget.invoice.paymentQrCode ?? '',
                invoiceCode: widget.invoice.invoiceCode,
                amountLabel: widget.amountLabel,
                onOpenCheckout: widget.invoice.paymentUrl?.isNotEmpty == true
                    ? () => Navigator.of(context)
                        .pop(PayOsPaymentDialogResult.openCheckout)
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isChecking) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      _isChecking
                          ? 'invoice_checking_payment'.tr
                          : 'invoice_waiting_payment'.tr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.profileTextMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (_lastError != null) ...[
                const SizedBox(height: 8),
                Text(
                  _lastError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PayOsPaymentDialogResult.payLater),
          child: Text('invoice_dialog_btn_later'.tr),
        ),
        if (widget.invoice.paymentUrl?.isNotEmpty == true)
          FilledButton(
            onPressed: () => Navigator.of(context)
                .pop(PayOsPaymentDialogResult.openCheckout),
            child: Text('invoice_pay_now'.tr),
          ),
      ],
    );
  }
}
