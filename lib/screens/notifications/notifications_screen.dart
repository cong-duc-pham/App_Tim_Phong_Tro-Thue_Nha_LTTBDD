import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/settings/app_settings_controller.dart';
import '../../core/theme/profile_theme.dart';
import '../../models/app_notification.dart';
import '../../repositories/notification_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationRepository _repository = NotificationRepository();
  List<AppNotification> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    notificationsEnabledNotifier.addListener(_handleNotificationSettingChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    notificationsEnabledNotifier
        .removeListener(_handleNotificationSettingChanged);
    super.dispose();
  }

  void _handleNotificationSettingChanged() {
    if (!mounted) return;
    if (!notificationsEnabledNotifier.value) {
      setState(() {
        _items = [];
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _repository.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = items;
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

  Future<void> _markAsRead(AppNotification item) async {
    if (item.isRead) return;

    setState(() {
      _items = _items
          .map((current) => current.id == item.id
              ? AppNotification(
                  id: current.id,
                  userId: current.userId,
                  title: current.title,
                  body: current.body,
                  type: current.type,
                  refId: current.refId,
                  refType: current.refType,
                  isRead: true,
                  sentAt: current.sentAt,
                )
              : current)
          .toList();
    });

    try {
      await _repository.markAsRead(item.id);
    } catch (_) {
      if (mounted) _loadNotifications();
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    await _markAsRead(item);
    if (!mounted) return;

    final type = item.type.toLowerCase();
    final refType = item.refType?.toLowerCase() ?? '';
    final refId = item.refId;

    final isViewingAppointment = type.contains('appointment') ||
        refType == 'viewing_appointment';

    if (isViewingAppointment) {
      context.push(AppConstants.routeViewingAppointments);
      return;
    }

    if (refId != null &&
        (type == 'listing_reviewed' ||
            type.contains('review') ||
            refType == 'review')) {
      context.push('/listing/$refId?section=reviews');
      return;
    }

    if (refId != null &&
        (type.contains('listing') || refType.contains('listing'))) {
      context.push('/listing/$refId');
    }
  }

  String _cleanError(Object e) {
    final message = e.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  String _timeLabel(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'notif_just_now'.tr;
    if (diff.inHours < 1) return '${diff.inMinutes} ${'notif_mins_ago'.tr}';
    if (diff.inDays < 1) return '${diff.inHours} ${'notif_hours_ago'.tr}';
    if (diff.inDays < 7) return '${diff.inDays} ${'notif_days_ago'.tr}';
    return '${local.day}/${local.month}/${local.year}';
  }

  IconData _iconFor(AppNotification item) {
    final type = item.type.toLowerCase();
    final refType = item.refType?.toLowerCase() ?? '';
    if (type.contains('appointment') || refType == 'viewing_appointment') {
      return Icons.event_available_outlined;
    }
    if (type.contains('chat') || refType.contains('chat')) {
      return Icons.chat_bubble_outline_rounded;
    }
    if (type.contains('listing') || refType.contains('listing')) {
      return Icons.home_work_outlined;
    }
    if (type.contains('payment') || refType.contains('payment')) {
      return Icons.payments_outlined;
    }
    if (type.contains('report') || refType.contains('report')) {
      return Icons.flag_outlined;
    }
    if (type.contains('vip')) return Icons.workspace_premium_outlined;
    return Icons.notifications_none_rounded;
  }

  Color _colorFor(AppNotification item) {
    final type = item.type.toLowerCase();
    final refType = item.refType?.toLowerCase() ?? '';
    if (type.contains('appointment') || refType == 'viewing_appointment') {
      return AppColors.warning;
    }
    if (type.contains('payment')) return AppColors.success;
    if (type.contains('report') || refType.contains('report')) {
      return AppColors.info;
    }
    if (type.contains('vip')) return AppColors.warning;
    if (type.contains('listing')) return AppColors.primary;
    if (type.contains('chat')) return AppColors.info;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((item) => !item.isRead).length;

    return Scaffold(
      backgroundColor: context.profileBg,
      body: Column(
        children: [
          _Header(unreadCount: unreadCount),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadNotifications,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (!notificationsEnabledNotifier.value) {
      return ListView(
        padding: const EdgeInsets.all(AppConstants.paddingH),
        children: [
          const SizedBox(height: 120),
          _StateBox(
            icon: Icons.notifications_off_outlined,
            title: 'notifications_off_title'.tr,
            message: 'notifications_off_desc'.tr,
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(AppConstants.paddingH),
        children: [
          const SizedBox(height: 120),
          _StateBox(
            icon: Icons.wifi_off_rounded,
            title: 'notif_load_failed'.tr,
            message: _errorMessage!,
            actionLabel: 'notif_retry'.tr,
            onAction: _loadNotifications,
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AppConstants.paddingH),
        children: [
          const SizedBox(height: 120),
          _StateBox(
            icon: Icons.notifications_none_rounded,
            title: 'notif_empty'.tr,
            message: 'notif_empty_desc'.tr,
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return _NotificationTile(
          item: item,
          icon: _iconFor(item),
          color: _colorFor(item),
          timeLabel: _timeLabel(item.sentAt),
          onTap: () => _openNotification(item),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final int unreadCount;

  const _Header({required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(AppConstants.routeHome),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'notif_title'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusFull),
                      ),
                      child: Text(
                        '$unreadCount ${'notif_unread_suffix'.tr}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 20,
              decoration: BoxDecoration(
                color: context.profileBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final IconData icon;
  final Color color;
  final String timeLabel;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.icon,
    required this.color,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? context.profileCard : context.profileSubtleCard,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: item.isRead
                ? context.profileBorder
                : AppColors.primary.withValues(alpha: 0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.profileText,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 5),
                          decoration: const BoxDecoration(
                            color: AppColors.notifDot,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.body.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.profileTextSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                  if (timeLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      timeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.profileTextMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _StateBox({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: context.profileSubtleCard,
              borderRadius: BorderRadius.circular(AppConstants.radiusXxl),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 38),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.profileText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.profileTextSecondary,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
