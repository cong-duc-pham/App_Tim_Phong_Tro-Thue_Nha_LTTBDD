import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/localization/app_localizations.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Load saved theme mode
  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString(AppConstants.keyThemeMode) ?? 'light';
  ThemeMode initialTheme = ThemeMode.light;
  if (themeStr == 'dark') {
    initialTheme = ThemeMode.dark;
  } else if (themeStr == 'system') {
    initialTheme = ThemeMode.system;
  }
  themeNotifier.value = initialTheme;

  // Load saved language
  final langStr = prefs.getString(AppConstants.keyAppLanguage) ?? 'vi';
  languageNotifier.value = langStr;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, _) {
        return ValueListenableBuilder<String>(
          valueListenable: languageNotifier,
          builder: (context, currentLanguage, _) {
            return MaterialApp.router(
              title: 'Swings House',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: currentThemeMode,
              routerConfig: appRouter,
            );
          },
        );
      },
    );
  }
}