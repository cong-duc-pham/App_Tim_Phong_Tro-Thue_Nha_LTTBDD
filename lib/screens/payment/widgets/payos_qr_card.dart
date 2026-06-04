import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/profile_theme.dart';

class PayOsQrCard extends StatelessWidget {
  const PayOsQrCard({
    super.key,
    required this.qrCode,
    required this.invoiceCode,
    required this.amountLabel,
    this.onOpenCheckout,
  });

  final String qrCode;
  final String invoiceCode;
  final String amountLabel;
  final VoidCallback? onOpenCheckout;

  @override
  Widget build(BuildContext context) {
    final hasQr = qrCode.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: context.profileBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'invoice_qr_title'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.profileText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'invoice_qr_desc'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: context.profileTextSecondary,
            ),
          ),
          const SizedBox(height: 14),
          if (hasQr)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: QrImageView(
                data: qrCode,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: Text(
                'invoice_qr_unavailable'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 14),
          _QrInfoRow(label: 'invoice_card_code'.tr, value: invoiceCode),
          const SizedBox(height: 6),
          _QrInfoRow(label: 'invoice_card_amount'.tr, value: amountLabel),
          if (onOpenCheckout != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenCheckout,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('invoice_open_checkout'.tr),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrInfoRow extends StatelessWidget {
  const _QrInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.profileTextMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.profileText,
            ),
          ),
        ),
      ],
    );
  }
}
