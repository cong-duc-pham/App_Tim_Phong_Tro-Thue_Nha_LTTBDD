// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ─── Màu chủ đạo ────────────────────────────────────────────────────────
  static const Color primary        = Color(0xFF0057D9); // Xanh dương chính
  static const Color primaryDark    = Color(0xFF0A3D8F); // Xanh dương đậm
  static const Color primaryLight   = Color(0xFFDBEAFE); // Xanh dương nhạt
  static const Color primaryMedium  = Color(0xFF185FA5); // Xanh dương vừa

  // ─── Màu nền ────────────────────────────────────────────────────────────
  static const Color bgPage         = Color(0xFFF5F7FA); // Nền trang
  static const Color bgCard         = Color(0xFFFFFFFF); // Nền thẻ
  static const Color bgCardLight    = Color(0xFFF1F5F9); // Nền thẻ nhạt

  // ─── Màu chữ ────────────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF0F172A); // Chữ đậm chính
  static const Color textSecondary  = Color(0xFF475569); // Chữ phụ
  static const Color textMuted      = Color(0xFF94A3B8); // Chữ mờ / hint
  static const Color textDark       = Color(0xFF1E293B); // Chữ tối

  // ─── Màu viền ───────────────────────────────────────────────────────────
  static const Color border         = Color(0xFFE2E8F0); // Viền mặc định
  static const Color borderLight    = Color(0xFFF1F5F9); // Viền nhạt

  // ─── Màu trạng thái ─────────────────────────────────────────────────────
  static const Color success        = Color(0xFF10B981); // Xanh lá - thành công
  static const Color successBg      = Color(0xFFDCFCE7); // Nền xanh lá nhạt
  static const Color successText    = Color(0xFF166534); // Chữ xanh lá đậm

  static const Color warning        = Color(0xFFF59E0B); // Vàng - cảnh báo
  static const Color warningBg      = Color(0xFFFFF7ED); // Nền vàng nhạt
  static const Color warningText    = Color(0xFF9A3412); // Chữ cam đậm

  static const Color error          = Color(0xFFE11D48); // Đỏ - lỗi / yêu thích
  static const Color errorBg        = Color(0xFFFFF1F2); // Nền đỏ nhạt

  static const Color info           = Color(0xFF3B82F6); // Xanh - thông tin
  static const Color infoBg         = Color(0xFFEFF6FF); // Nền xanh nhạt

  // ─── Màu danh mục phòng ─────────────────────────────────────────────────
  static const Color catBlue        = Color(0xFFDBEAFE); // Phòng trọ SV
  static const Color catIndigo      = Color(0xFFE0E7FF); // Căn hộ DV
  static const Color catCyan        = Color(0xFFCFFAFE); // Ở ghép
  static const Color catSky         = Color(0xFFE0F2FE); // Nhà nguyên căn

  // ─── Màu nền illustration ───────────────────────────────────────────────
  static const Color illus1         = Color(0xFFBFDBFE); // Slide / card 1
  static const Color illus2         = Color(0xFFA5F3FC); // Slide / card 2
  static const Color illus3         = Color(0xFFC7D2FE); // Slide / card 3
  static const Color illus4         = Color(0xFFBAE6FD); // Slide / card 4

  // ─── Màu tag / badge ────────────────────────────────────────────────────
  static const Color tagVip         = Color(0xFF0057D9); // Badge VIP xanh
  static const Color tagNew         = Color(0xFF10B981); // Badge MỚI xanh lá
  static const Color tagHot         = Color(0xFFF59E0B); // Badge HOT vàng

  // ─── Màu bottom nav ─────────────────────────────────────────────────────
  static const Color navActive      = Color(0xFF0057D9); // Tab đang chọn
  static const Color navInactive    = Color(0xFF94A3B8); // Tab chưa chọn

  // ─── Màu notification dot ───────────────────────────────────────────────
  static const Color notifDot       = Color(0xFFFF6B35); // Chấm thông báo cam

  // Illustration chi tiết - onboarding
  static const Color windowBlue    = Color(0xFFB5D4F4);
  static const Color windowBorder  = Color(0xFF85B7EB);
  static const Color mapPinGreen   = Color(0xFF10B981);
  static const Color mapPinYellow  = Color(0xFFF59E0B);
  static const Color chatTextDark  = Color(0xFF1E293B);
}