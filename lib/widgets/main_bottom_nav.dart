import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/constants/app_text_styles.dart';
import '../services/post_listing_draft_service.dart';

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      padding: EdgeInsets.only(
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        children: [
          _NavItem(
            icon: Icons.home_rounded,
            label: 'Trang chủ',
            active: path == AppConstants.routeHome,
            onTap: () => _goTo(context, AppConstants.routeHome),
          ),
          _NavItem(
            icon: Icons.favorite_border_rounded,
            label: 'Yêu thích',
            active: path == AppConstants.routeFavorites,
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
                const Text('Đăng tin', style: AppTextStyles.navLabel),
              ],
            ),
          ),
          _NavItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Tin nhắn',
            active: path == AppConstants.routeChat,
            onTap: () => _goTo(context, AppConstants.routeChat),
          ),
          _NavItem(
            icon: Icons.person_outline_rounded,
            label: 'Cá nhân',
            active: path == AppConstants.routeProfile,
            onTap: () => _goTo(context, AppConstants.routeProfile),
          ),
        ],
      ),
    );
  }

  Future<void> _goTo(BuildContext context, String route) async {
    final currentPath = GoRouterState.of(context).uri.path;
    if (currentPath == route) return;

    if (currentPath == AppConstants.routePostListing &&
        PostListingDraftService.hasDraft.value) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Bỏ thông tin đang nhập?'),
          content: const Text(
            'Bạn đang nhập dở tin đăng. Nếu rời khỏi trang này, thông tin chưa đăng sẽ bị mất.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Ở lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Rời trang'),
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
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppConstants.iconLg,
              color: active ? AppColors.navActive : AppColors.navInactive,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTextStyles.navLabel.copyWith(
                color: active ? AppColors.navActive : AppColors.navInactive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
