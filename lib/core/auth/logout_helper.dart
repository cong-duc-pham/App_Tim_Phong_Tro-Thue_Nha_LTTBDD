import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/auth_repository.dart';
import '../constants/app_constants.dart';
import '../constants/router_keys.dart';

class LogoutHelper {
  const LogoutHelper._();

  static Future<void> signOutAndGoToLogin([GoRouter? router]) async {
    try {
      await AuthRepository().signOut();
    } catch (e, stackTrace) {
      debugPrint('Logout failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      final stableContext = rootNavigatorKey.currentContext;
      if (stableContext != null && stableContext.mounted) {
        GoRouter.of(stableContext).go(AppConstants.routeLogin);
      } else {
        router?.go(AppConstants.routeLogin);
      }
    }
  }
}
