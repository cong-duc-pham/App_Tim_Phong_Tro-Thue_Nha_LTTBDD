// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../constants/app_constants.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryMedium,
        surface: AppColors.bgCard,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.bgPage,

      // ─── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      // ─── ElevatedButton ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.btnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      // ─── OutlinedButton ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.btnSecondary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      // ─── TextButton ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.btnSecondary,
        ),
      ),

      // ─── InputDecoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: AppTextStyles.inputHint,
        labelStyle: AppTextStyles.inputLabel,
        errorStyle: AppTextStyles.inputError,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),

      // ─── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          side: const BorderSide(color: AppColors.borderLight),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── BottomNavigationBar ─────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.navActive,
        unselectedItemColor: AppColors.navInactive,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: AppTextStyles.navLabel,
        unselectedLabelStyle: AppTextStyles.navLabel,
      ),

      // ─── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
      ),

      // ─── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.primaryMedium,
        surface: const Color(0xFF1E293B),
        brightness: Brightness.dark,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900

      // ─── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E293B), // Slate 800
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      // ─── ElevatedButton ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.btnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      // ─── OutlinedButton ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.btnSecondary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),

      // ─── TextButton ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.btnSecondary,
        ),
      ),

      // ─── InputDecoration ─────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        hintStyle: const TextStyle(fontSize: 14, color: Colors.white38),
        labelStyle: const TextStyle(fontSize: 14, color: Colors.white70),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: Colors.white10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),

      // ─── Card ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          side: const BorderSide(color: Colors.white10),
        ),
        margin: EdgeInsets.zero,
      ),

      // ─── BottomNavigationBar ─────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF0F172A),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white38,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ─── Chip ────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF1E293B),
        selectedColor: AppColors.primary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          side: const BorderSide(color: Colors.white10, width: 1.5),
        ),
      ),

      // ─── Divider ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Colors.white10,
        thickness: 1,
        space: 0,
      ),
    );
  }
}