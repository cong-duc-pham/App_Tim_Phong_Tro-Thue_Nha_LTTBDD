import 'package:go_router/go_router.dart';

import '../../repositories/auth_repository.dart';
import '../constants/app_constants.dart';

class LogoutHelper {
  const LogoutHelper._();

  static Future<void> signOutAndGoToLogin(GoRouter router) async {
    await AuthRepository().signOut();
    router.go(AppConstants.routeLogin);
  }
}
