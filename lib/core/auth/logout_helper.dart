import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/auth_repository.dart';
import '../../services/chat_unread_service.dart';
import '../constants/app_constants.dart';
import '../constants/router_keys.dart';

class LogoutHelper {
  const LogoutHelper._();

  static Future<void> signOutAndGoToLogin([GoRouter? router]) async {
    try {
      await AuthRepository().signOut().timeout(const Duration(seconds: 8));
    } catch (e, stackTrace) {
      debugPrint('Logout failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      try {
        await ChatUnreadService.stopAndClear().timeout(
          const Duration(seconds: 4),
        );
      } catch (e) {
        debugPrint('Chat cleanup during logout skipped: $e');
      }
      final stableContext = rootNavigatorKey.currentContext;
      if (stableContext != null && stableContext.mounted) {
        GoRouter.of(stableContext).go(AppConstants.routeLogin);
      } else {
        router?.go(AppConstants.routeLogin);
      }
    }
  }
}
