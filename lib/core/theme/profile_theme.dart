import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

extension ProfileTheme on BuildContext {
  bool get isDarkProfile => Theme.of(this).brightness == Brightness.dark;

  Color get profileBg =>
      isDarkProfile ? const Color(0xFF0F172A) : AppColors.bgPage;

  Color get profileCard =>
      isDarkProfile ? const Color(0xFF1E293B) : Colors.white;

  Color get profileSubtleCard =>
      isDarkProfile ? const Color(0xFF111827) : AppColors.bgCardLight;

  Color get profileBorder =>
      isDarkProfile ? Colors.white10 : AppColors.borderLight;

  Color get profileText => isDarkProfile ? Colors.white : AppColors.textPrimary;

  Color get profileTextSecondary =>
      isDarkProfile ? Colors.white70 : AppColors.textSecondary;

  Color get profileTextMuted =>
      isDarkProfile ? Colors.white54 : AppColors.textMuted;

  Color get profileInputFill =>
      isDarkProfile ? const Color(0xFF111827) : Colors.white;
}
