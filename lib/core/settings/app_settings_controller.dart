import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../localization/app_localizations.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<bool> notificationsEnabledNotifier = ValueNotifier(true);

Future<void> loadAppSettings() async {
  final prefs = await SharedPreferences.getInstance();

  final themeStr = prefs.getString(AppConstants.keyThemeMode) ?? 'light';
  themeNotifier.value = switch (themeStr) {
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => ThemeMode.light,
  };

  languageNotifier.value = prefs.getString(AppConstants.keyAppLanguage) ?? 'vi';
  notificationsEnabledNotifier.value =
      prefs.getBool(AppConstants.keyNotificationsEnabled) ?? true;
}

Future<void> saveThemeMode(ThemeMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  final modeStr = switch (mode) {
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
    ThemeMode.light => 'light',
  };

  await prefs.setString(AppConstants.keyThemeMode, modeStr);
  themeNotifier.value = mode;
}

Future<void> saveAppLanguage(String langCode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(AppConstants.keyAppLanguage, langCode);
  languageNotifier.value = langCode;
}

Future<void> saveNotificationsEnabled(bool value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(AppConstants.keyNotificationsEnabled, value);
  notificationsEnabledNotifier.value = value;
}
