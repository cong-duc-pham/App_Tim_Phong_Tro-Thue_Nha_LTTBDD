import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';
import '../../models/post_package.dart';
import '../../repositories/package_repository.dart';

class PackageScreen extends StatefulWidget {
  const PackageScreen({super.key, this.listingId, this.initialPackageId});

  final int? listingId;
  final int? initialPackageId;

  @override
  State<PackageScreen> createState() => _PackageScreenState();
}

class _PackageScreenState extends State<PackageScreen> {
  final PackageRepository _repository = PackageRepository();
  List<PostPackage> _packages = [];
  bool _isLoading = true;
  int? _purchasingPackageId;
  bool _isSimulatingPayment = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final packages = await _repository.getPackages();
      if (!mounted) return;
      setState(() {
        _packages = _sortPackages(packages);
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

  List<PostPackage> _sortPackages(List<PostPackage> packages) {
    final selectedId = widget.initialPackageId;
    if (selectedId == null) return packages;
    return [...packages]..sort((a, b) {
        if (a.packageId == selectedId) return -1;
        if (b.packageId == selectedId) return 1;
        return a.price.compareTo(b.price);
      });
  }

  Future<void> _purchase(PostPackage package) async {
    final listingId = widget.listingId;
    if (listingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('post_package_must_post_first'.tr),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (package.isFree) {
      _goAfterCurrentFrame(AppConstants.routeHome);
      return;
    }

    setState(() => _purchasingPackageId = package.packageId);
    try {
      final invoice = await _repository.purchasePackage(
        listingId: listingId,
        packageId: package.packageId,
      );
      if (!mounted) return;
      final shouldSimulate = await _showInvoiceDialog(
        invoiceCode: invoice.invoiceCode,
        amount: invoice.totalAmount,
        packageName: package.packageName,
      );
      if (!mounted) return;

      if (shouldSimulate == true) {
        await _simulatePayment(invoice.invoiceCode);
      } else {
        _goAfterCurrentFrame(AppConstants.routeHome);
      }
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
      if (mounted) setState(() => _purchasingPackageId = null);
    }
  }

  Future<bool?> _showInvoiceDialog({
    required String invoiceCode,
    required double amount,
    required String packageName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('invoice_dialog_created_title'.tr),
        content: Text(
          'invoice_dialog_code'.tr.replaceAll('{code}', invoiceCode) + '\n' +
          'invoice_dialog_amount'.tr.replaceAll('{amount}', _formatPrice(amount)) + '\n\n' +
          'invoice_dialog_success_desc'.tr.replaceAll('{package}', packageName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('invoice_dialog_btn_later'.tr),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('invoice_dialog_btn_simulate'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _simulatePayment(String invoiceCode) async {
    setState(() => _isSimulatingPayment = true);
    try {
      await _repository.simulateMomoPayment(invoiceCode);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('invoice_pay_success'.tr),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _goAfterCurrentFrame(AppConstants.routeHome);
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
      if (mounted) setState(() => _isSimulatingPayment = false);
    }
  }

  void _goAfterCurrentFrame(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(route);
    });
  }

  String _cleanError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  String _formatPrice(double price) {
    if (price <= 0) return 'post_package_free'.tr;
    final raw = price.toInt().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write('.');
      buffer.write(raw[i]);
    }
    return '$bufferđ';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('invoice_vip_select'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppConstants.routeHome);
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 42, color: context.profileTextMuted),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.profileTextSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadPackages,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('common_retry'.tr),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _loadPackages,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _packages.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final package = _packages[index];
          return _PackagePlanCard(
            package: package,
            priceLabel: _formatPrice(package.price),
            isPopular: package.packageType == 'vip' &&
                package.durationDays >= 30 &&
                !package.isFeatured,
            isSelected: package.packageId == widget.initialPackageId,
            isPurchasing:
                _purchasingPackageId == package.packageId ||
                _isSimulatingPayment,
            onPressed: () => _purchase(package),
          );
        },
      ),
    );
  }
}

class _PackagePlanCard extends StatelessWidget {
  const _PackagePlanCard({
    required this.package,
    required this.priceLabel,
    required this.isPopular,
    required this.isSelected,
    required this.isPurchasing,
    required this.onPressed,
  });

  final PostPackage package;
  final String priceLabel;
  final bool isPopular;
  final bool isSelected;
  final bool isPurchasing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = package.isFeatured
        ? AppColors.tagHot
        : package.isVip
            ? AppColors.primary
            : AppColors.textSecondary;
    final features = _featuresFor(package);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.profileCard,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            border: Border.all(
              color: isSelected
                  ? accent
                  : isPopular
                      ? AppColors.primary
                      : context.profileBorder,
              width: isSelected || isPopular ? 1.7 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: context.isDarkProfile ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      package.packageName,
                      style: TextStyle(
                        color: accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (package.isFeatured)
                    const Icon(Icons.workspace_premium_rounded,
                        color: AppColors.tagHot),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.success),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                priceLabel,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: context.profileText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'post_package_days'.tr.replaceAll('{days}', '${package.durationDays}'),
                style: TextStyle(
                  color: context.profileTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Divider(height: 28, color: context.profileBorder),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        feature.enabled
                            ? Icons.check_rounded
                            : Icons.close_rounded,
                        size: 18,
                        color: feature.enabled ? accent : context.profileTextMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          feature.label,
                          style: TextStyle(
                            color: feature.enabled
                                ? context.profileText
                                : context.profileTextMuted,
                            fontWeight: feature.enabled
                                ? FontWeight.w600
                                : FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isPurchasing ? null : onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    ),
                  ),
                  child: isPurchasing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(package.isFree ? 'post_package_use_free'.tr : 'post_package_choose'.tr),
                ),
              ),
            ],
          ),
        ),
        if (isPopular)
          Positioned(
            top: -10,
            right: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              ),
              child: Text(
                'post_package_popular'.tr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<_PlanFeature> _featuresFor(PostPackage package) {
    return [
      _PlanFeature(
        package.priority == 0
            ? 'post_feature_show_normal'.tr
            : package.isFeatured
                ? 'post_feature_highest_priority'.tr
                : package.priority >= 2
                    ? 'post_feature_high_priority'.tr
                    : 'post_feature_priority'.tr,
        true,
      ),
      _PlanFeature(
        package.maxImages >= 99
            ? 'post_feature_unlimited_images'.tr
            : 'post_feature_max_images'.tr.replaceAll('{max}', '${package.maxImages}'),
        true,
      ),
      _PlanFeature(
        package.badgeType == 'featured'
            ? 'post_feature_badge_gold'.tr
            : 'post_feature_badge_blue'.tr,
        package.badgeType != null,
      ),
      _PlanFeature('post_feature_banner'.tr, package.allowBanner),
      _PlanFeature(
        'post_feature_max_videos'.tr.replaceAll('{max}', '${package.maxVideos}'),
        package.maxVideos > 0,
      ),
      _PlanFeature(
        package.isFeatured ? 'post_feature_analytics_detailed'.tr : 'post_feature_analytics_views'.tr,
        package.hasAnalytics,
      ),
    ];
  }
}

class _PlanFeature {
  final String label;
  final bool enabled;

  const _PlanFeature(this.label, this.enabled);
}
