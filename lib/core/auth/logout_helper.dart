import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../repositories/auth_repository.dart';
import '../constants/app_constants.dart';

class LogoutHelper {
  const LogoutHelper._();

  static Future<void> signOutAndGoToLogin(GoRouter router) async {
    try {
      await AuthRepository().signOut();
    } catch (e, stackTrace) {
      debugPrint('Logout failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      router.go(AppConstants.routeLogin);
    }
  }
}
