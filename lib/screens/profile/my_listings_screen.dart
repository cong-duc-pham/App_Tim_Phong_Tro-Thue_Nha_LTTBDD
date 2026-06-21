import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/profile_theme.dart';
import '../../models/listing.dart';
import '../../repositories/listing_repository.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final ListingRepository _repository = ListingRepository();
  late Future<List<Listing>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.getMyListings();
  }

  Future<void> _refresh() async {
    setState(() => _future = _repository.getMyListings());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('profile_my_listings'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<List<Listing>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: _cleanError(snapshot.error),
              onRetry: _refresh,
            );
          }

          final listings = snapshot.data ?? const <Listing>[];
          if (listings.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: listings.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final listing = listings[index];
                return _MyListingCard(
                  listing: listing,
                  onRefresh: _refresh,
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _cleanError(Object? error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}

class ListingAnalyticsScreen extends StatefulWidget {
  const ListingAnalyticsScreen({
    super.key,
    required this.listingId,
    this.initialListing,
  });

  final int listingId;
  final Listing? initialListing;

  @override
  State<ListingAnalyticsScreen> createState() => _ListingAnalyticsScreenState();
}

class _ListingAnalyticsScreenState extends State<ListingAnalyticsScreen> {
  final ListingRepository _repository = ListingRepository();
  late Future<Listing> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadListing();
  }

  Future<Listing> _loadListing() async {
    final myListings = await _repository.getMyListings();
    final matches =
        myListings.where((item) => item.listingId == widget.listingId);
    if (matches.isNotEmpty) return matches.first;
    if (widget.initialListing != null) return widget.initialListing!;
    throw Exception('mylistings_not_found'.tr);
  }

  Future<void> _refresh() async {
    setState(() => _future = _loadListing());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.profileBg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('mylistings_analytics_title'.tr),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<Listing>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return _ErrorState(
              message: _cleanError(snapshot.error),
              onRetry: _refresh,
            );
          }

          final listing = snapshot.data!;
          if (!listing.hasAnalytics) {
            return _AnalyticsLocked(listing: listing);
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AnalyticsHeader(listing: listing),
                const SizedBox(height: 14),
                _MetricGrid(listing: listing),
                const SizedBox(height: 14),
                _EngagementCard(listing: listing),
                const SizedBox(height: 14),
                _ListingHealthCard(listing: listing),
              ],
            ),
          );
        },
      ),
    );
  }

  String _cleanError(Object? error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }
}

class _MyListingCard extends StatelessWidget {
  const _MyListingCard({
    required this.listing,
    this.onRefresh,
  });

  final Listing listing;
  final VoidCallback? onRefresh;

  Future<void> _handleToggleStatus(BuildContext context) async {
    final isCurrentlyVisible = listing.statusName.toLowerCase() == 'active';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isCurrentlyVisible
              ? 'mylistings_hide_confirm_title'.tr
              : 'mylistings_show_confirm_title'.tr,
        ),
        content: Text(
          isCurrentlyVisible
              ? 'mylistings_hide_confirm_desc'.tr
              : 'mylistings_show_confirm_desc'.tr,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('cancel'.tr),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor:
                  isCurrentlyVisible ? Colors.orange : AppColors.success,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              isCurrentlyVisible
                  ? 'mylistings_hide_listing'.tr
                  : 'mylistings_show_listing'.tr,
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final repository = ListingRepository();
      final updated = await repository.toggleListingStatus(listing.listingId);

      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        final message = updated.statusName.toLowerCase() == 'hidden'
            ? 'mylistings_hide_success'.tr
            : 'mylistings_show_success'.tr;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (onRefresh != null) {
        onRefresh!();
      }
    } catch (e) {
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleEdit(BuildContext context) async {
    final router = GoRouter.of(context);
    Listing listingForEdit = listing;

    try {
      listingForEdit =
          await ListingRepository().getListingById(listing.listingId);
    } catch (_) {
      // Vẫn cho phép chỉnh sửa dữ liệu đã có nếu không thể tải chi tiết.
    }

    if (!context.mounted) return;
    router.go(
      AppConstants.routePostListing,
      extra: listingForEdit,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canViewAnalytics = listing.hasAnalytics;

    Color statusColor;
    String statusLabel;
    switch (listing.statusName.toLowerCase()) {
      case 'active':
        statusColor = AppColors.success;
        statusLabel = 'mylistings_status_active'.tr;
        break;
      case 'rented':
        statusColor = AppColors.error;
        statusLabel = 'home_status_rented'.tr;
        break;
      case 'hidden':
        statusColor = Colors.orange;
        statusLabel = 'mylistings_status_hidden'.tr;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        statusLabel = 'mylistings_tab_pending'.tr;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusLabel = 'mylistings_tab_rejected'.tr;
        break;
      case 'expired':
        statusColor = context.profileTextSecondary;
        statusLabel = 'mylistings_status_expired'.tr;
        break;
      default:
        statusColor = context.profileTextSecondary;
        statusLabel = listing.statusName.isEmpty
            ? 'mylistings_status_processing'.tr
            : listing.statusName;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ListingThumb(url: listing.image0, size: 74),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: context.profileText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      listing.displayAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.profileTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _MiniBadge(
                          label: statusLabel,
                          color: statusColor,
                        ),
                        if (listing.packageName != null)
                          _MiniBadge(
                            label: listing.packageName!,
                            color: listing.hasAnalytics
                                ? AppColors.primary
                                : context.profileTextSecondary,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineMetric(
                  icon: Icons.visibility_outlined,
                  label: 'mylistings_views_label'.tr,
                  value: '${listing.viewCount ?? 0}',
                ),
              ),
              Expanded(
                child: _InlineMetric(
                  icon: Icons.bookmark_border_rounded,
                  label: 'mylistings_saved_label'.tr,
                  value: '${listing.saveCount ?? 0}',
                ),
              ),
              Expanded(
                child: _InlineMetric(
                  icon: Icons.rate_review_outlined,
                  label: 'mylistings_reviews_label'.tr,
                  value: '${listing.reviewCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (canViewAnalytics) ...[
                Expanded(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () => context.push(
                      '${AppConstants.routeListingAnalytics}/${listing.listingId}',
                      extra: listing,
                    ),
                    icon: const Icon(Icons.analytics_outlined, size: 16),
                    label: Text(
                      'mylistings_analytics'.tr,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: () => _handleEdit(context),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Sửa tin', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: listing.statusName.toLowerCase() == 'rented'
                    ? FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.lock_clock_outlined, size: 16),
                        label: Text(
                          'home_status_rented'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: FilledButton.styleFrom(
                          disabledBackgroundColor:
                              AppColors.error.withValues(alpha: 0.12),
                          disabledForegroundColor: AppColors.error,
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed:
                            (listing.statusName.toLowerCase() == 'active' ||
                                    listing.statusName.toLowerCase() == 'hidden')
                                ? () => _handleToggleStatus(context)
                                : null,
                        icon: Icon(
                          listing.statusName.toLowerCase() == 'active'
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 16,
                        ),
                        label: Text(
                          listing.statusName.toLowerCase() == 'active'
                              ? 'mylistings_hide_listing'.tr
                              : 'mylistings_show_listing'.tr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              listing.statusName.toLowerCase() == 'active'
                                  ? Colors.orange
                                  : AppColors.success,
                          side: BorderSide(
                            color: listing.statusName.toLowerCase() == 'active'
                                ? Colors.orange
                                : AppColors.success,
                          ),
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

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: Row(
        children: [
          _ListingThumb(url: listing.image0, size: 78),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.profileText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  listing.packageName ?? 'mylistings_normal_package'.tr,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.displayAddress,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.profileTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _MetricCard(
          icon: Icons.visibility_outlined,
          label: 'mylistings_views_label'.tr,
          value: '${listing.viewCount ?? 0}',
          color: AppColors.primary,
        ),
        _MetricCard(
          icon: Icons.bookmark_border_rounded,
          label: 'mylistings_saved_count'.tr,
          value: '${listing.saveCount ?? 0}',
          color: AppColors.success,
        ),
        _MetricCard(
          icon: Icons.star_border_rounded,
          label: 'mylistings_rating_score'.tr,
          value: listing.averageRating > 0
              ? listing.averageRating.toStringAsFixed(1)
              : '0.0',
          color: AppColors.warning,
        ),
        _MetricCard(
          icon: Icons.rate_review_outlined,
          label: 'mylistings_reviews_count'.tr,
          value: '${listing.reviewCount}',
          color: AppColors.info,
        ),
      ],
    );
  }
}

class _EngagementCard extends StatelessWidget {
  const _EngagementCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final views = listing.viewCount ?? 0;
    final saves = listing.saveCount ?? 0;
    final reviews = listing.reviewCount;
    final engagement = views == 0 ? 0.0 : ((saves + reviews) / views) * 100;

    return _Panel(
      title: 'mylistings_engagement'.tr,
      icon: Icons.trending_up_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressMetric(
            label: 'mylistings_save_rate'.tr,
            value: views == 0 ? 0 : saves / views,
            valueLabel: views == 0
                ? '0%'
                : '${((saves / views) * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 14),
          _ProgressMetric(
            label: 'mylistings_review_rate'.tr,
            value: views == 0 ? 0 : reviews / views,
            valueLabel: views == 0
                ? '0%'
                : '${((reviews / views) * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 14),
          _ProgressMetric(
            label: 'mylistings_total_engagement'.tr,
            value: (engagement / 100).clamp(0, 1),
            valueLabel: '${engagement.toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _ListingHealthCard extends StatelessWidget {
  const _ListingHealthCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final imageScore = (listing.allImages.length / 6).clamp(0.0, 1.0);
    final contactScore =
        listing.landlordPhone?.trim().isNotEmpty == true ? 1.0 : 0.0;
    final locationScore = listing.hasLocation ? 1.0 : 0.0;

    return _Panel(
      title: 'mylistings_listing_quality'.tr,
      icon: Icons.insights_rounded,
      child: Column(
        children: [
          _ProgressMetric(
            label: 'mylistings_photo_completeness'.tr,
            value: imageScore,
            valueLabel: '${listing.allImages.length}/6',
          ),
          const SizedBox(height: 14),
          _ProgressMetric(
            label: 'mylistings_contact_info'.tr,
            value: contactScore,
            valueLabel: contactScore == 1
                ? 'mylistings_available'.tr
                : 'mylistings_missing'.tr,
          ),
          const SizedBox(height: 14),
          _ProgressMetric(
            label: 'mylistings_map_location'.tr,
            value: locationScore,
            valueLabel: locationScore == 1
                ? 'mylistings_available'.tr
                : 'mylistings_missing'.tr,
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLocked extends StatelessWidget {
  const _AnalyticsLocked({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 46, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'mylistings_locked_title'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.profileText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              listing.packageName == null
                  ? 'mylistings_locked_buy_vip'.tr
                  : 'mylistings_locked_package'
                      .tr
                      .replaceAll('{package}', listing.packageName!),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.profileTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: context.profileText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.profileCard,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: context.profileBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Text(
            value,
            style: TextStyle(
              color: context.profileText,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.profileTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({
    required this.label,
    required this.value,
    required this.valueLabel,
  });

  final String label;
  final double value;
  final String valueLabel;

  @override
  Widget build(BuildContext context) {
    final progress = value.clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: context.profileText,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            Text(
              valueLabel,
              style: TextStyle(
                color: context.profileTextSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: context.profileBorder,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: context.profileText,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: context.profileTextMuted, fontSize: 10),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ListingThumb extends StatelessWidget {
  const _ListingThumb({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageUrl = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: Container(
        width: size,
        height: size,
        color: AppColors.primaryLight,
        child: imageUrl == null || imageUrl.trim().isEmpty
            ? const Icon(Icons.home_work_outlined, color: AppColors.primary)
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.home_work_outlined,
                  color: AppColors.primary,
                ),
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 44, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.profileTextSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text('common_retry'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_work_outlined,
                size: 46, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              'mylistings_empty'.tr,
              style: TextStyle(
                color: context.profileText,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'mylistings_empty_posted_desc'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.profileTextSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

extension _ListingAnalyticsFields on Listing {
  String? get packageName {
    final value = packageInfo?['packageName'] ?? packageInfo?['PackageName'];
    return value?.toString();
  }

  bool get hasAnalytics {
    final value = packageInfo?['hasAnalytics'] ?? packageInfo?['HasAnalytics'];
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString().toLowerCase() == 'true';
  }
}
