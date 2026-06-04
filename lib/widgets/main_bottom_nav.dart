import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_text_styles.dart';
import '../core/localization/app_localizations.dart';
import '../services/chat_unread_service.dart';
import '../services/post_listing_draft_service.dart';

class MainBottomNav extends StatefulWidget {
  const MainBottomNav({super.key});

  @override
  State<MainBottomNav> createState() => _MainBottomNavState();
}

class _MainBottomNavState extends State<MainBottomNav>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ChatUnreadService.refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => ChatUnreadService.refresh(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ChatUnreadService.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final navTheme = Theme.of(context).bottomNavigationBarTheme;
    final bgColor =
        navTheme.backgroundColor ?? Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).dividerColor;
    final activeColor = navTheme.selectedItemColor ?? AppColors.navActive;
    final inactiveColor = navTheme.unselectedItemColor ?? AppColors.navInactive;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'nav_home'.tr,
            active: path == AppConstants.routeHome,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _goTo(context, AppConstants.routeHome),
          ),
          _NavItem(
            icon: Icons.favorite_border_rounded,
            label: 'nav_favorites'.tr,
            active: path == AppConstants.routeFavorites,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _goTo(context, AppConstants.routeFavorites),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _goTo(context, AppConstants.routePostListing),
                  child: Container(
                    width: AppConstants.navAddBtnSize,
                    height: AppConstants.navAddBtnSize,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                Text(
                  'nav_post'.tr,
                  style: AppTextStyles.navLabel.copyWith(
                    color: inactiveColor,
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: ChatUnreadService.unreadCount,
            builder: (context, unreadCount, child) {
              return _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                label: 'nav_chat'.tr,
                active: path == AppConstants.routeChat,
                badgeCount: unreadCount,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => _goTo(context, AppConstants.routeChat),
              );
            },
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'nav_profile'.tr,
            active: path == AppConstants.routeProfile,
            activeColor: activeColor,
            inactiveColor: inactiveColor,
            onTap: () => _goTo(context, AppConstants.routeProfile),
          ),
        ],
      ),
    );
  }

  Future<void> _goTo(BuildContext context, String route) async {
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath == route) return;

    if (route == AppConstants.routePostListing) {
      final prefs = await SharedPreferences.getInstance();
      final isPhoneVerified = prefs.getBool('verify_phone_status') ?? false;

      if (!isPhoneVerified) {
        if (!context.mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Yêu cầu xác thực',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Bạn cần xác thực số điện thoại trước khi có thể đăng tin mới. Xác thực ngay?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xác thực ngay'),
              ),
            ],
          ),
        );

        if (proceed == true && context.mounted) {
          context.push('/verify-account?isFromPostListing=true');
        }
        return;
      }
    }

    if (currentPath == AppConstants.routePostListing &&
        PostListingDraftService.hasDraft.value) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('leave_draft_title'.tr),
          content: Text('leave_draft_desc'.tr),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('stay'.tr),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('leave_page'.tr),
            ),
          ],
        ),
      );

      if (shouldLeave != true || !context.mounted) return;
      PostListingDraftService.clear();
    }

    if (context.mounted) context.go(route);
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavIconWithBadge(
              icon: icon,
              active: active,
              badgeCount: badgeCount,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.navLabel.copyWith(
                color: active ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIconWithBadge extends StatelessWidget {
  const _NavIconWithBadge({
    required this.icon,
    required this.active,
    required this.badgeCount,
    required this.activeColor,
    required this.inactiveColor,
  });

  final IconData icon;
  final bool active;
  final int badgeCount;
  final Color activeColor;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    final displayCount = badgeCount > 99 ? '99+' : '$badgeCount';

    return SizedBox(
      width: 34,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            icon,
            size: AppConstants.iconLg,
            color: active ? activeColor : inactiveColor,
          ),
          if (badgeCount > 0)
            Positioned(
              top: -2,
              right: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                height: 17,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.notifDot,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Theme.of(context)
                            .bottomNavigationBarTheme
                            .backgroundColor ??
                        Theme.of(context).colorScheme.surface,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  displayCount,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
