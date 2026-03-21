// lib/core/constants/app_text_styles.dart

import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  // ─── Heading ────────────────────────────────────────────────────────────
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    height: 1.3,
  );

  // ─── Section title (trang chủ) ──────────────────────────────────────────
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionLink = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  // ─── Body ───────────────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.6,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.5,
  );

  // ─── Card ───────────────────────────────────────────────────────────────
  static const TextStyle cardPrice = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
  );

  static const TextStyle cardPriceSub = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
    height: 1.3,
  );

  static const TextStyle cardTitleLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.3,
  );

  static const TextStyle cardAddress = TextStyle(
    fontSize: 10,
    color: AppColors.textMuted,
  );

  static const TextStyle cardTag = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w600,
    color: AppColors.info,
  );

  // ─── Button ─────────────────────────────────────────────────────────────
  static const TextStyle btnPrimary = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle btnSecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static const TextStyle btnSkip = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  // ─── Navigation ─────────────────────────────────────────────────────────
  static const TextStyle navLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
  );

  // ─── Form / Input ────────────────────────────────────────────────────────
  static const TextStyle inputHint = TextStyle(
    fontSize: 14,
    color: AppColors.textMuted,
  );

  static const TextStyle inputLabel = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textDark,
  );

  static const TextStyle inputError = TextStyle(
    fontSize: 11,
    color: AppColors.error,
  );

  // ─── Badge / Tag ─────────────────────────────────────────────────────────
  static const TextStyle badge = TextStyle(
    fontSize: 9,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle tagLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  // ─── Onboarding ──────────────────────────────────────────────────────────
  static const TextStyle onboardingTitle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    height: 1.25,
  );

  static const TextStyle onboardingDesc = TextStyle(
    fontSize: 13,
    color: Color(0xFF64748B),
    height: 1.6,
  );

  static const TextStyle onboardingTag = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  // ─── Splash ──────────────────────────────────────────────────────────────
  static const TextStyle splashAppName = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 2,
  );

  static const TextStyle splashTagline = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
    letterSpacing: 0.5,
  );

  static const TextStyle splashLogo = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    letterSpacing: 1,
  );
}