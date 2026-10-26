import 'package:flutter/material.dart';

@immutable
class StatusStyle {
  const StatusStyle({required this.fill, required this.soft, required this.text});
  final Color fill; // pins, dots, icons on neutral surfaces (3:1 vs surface)
  final Color soft; // chip background
  final Color text; // chip label and icon on soft (>= 4.5:1)
}

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textMuted,
    required this.primary,
    required this.onPrimary,
    required this.brand,
    required this.onBrand,
    required this.brandSoft,
    required this.brandMid,
    required this.brandLeaf,
    required this.accent,
    required this.onAccent,
    required this.accentStrong,
    required this.accentSoft,
    required this.error,
    required this.scrim,
    required this.statusReceived,
    required this.statusAssigned,
    required this.statusResolved,
    required this.statusEscalated,
  });

  final Color background, surface, surfaceMuted, border, borderStrong;
  final Color textPrimary, textMuted;
  final Color primary, onPrimary; // PRD token names kept. primary = INK (D-02)
  final Color brand, onBrand, brandSoft, brandMid, brandLeaf;
  final Color accent, onAccent, accentStrong, accentSoft;
  final Color error, scrim;
  final StatusStyle statusReceived, statusAssigned, statusResolved, statusEscalated;

  static const light = AppColors(
    background: Color(0xFFF3F6F2),
    surface: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFE9F1E6),
    border: Color(0xFFDCE5D9),
    borderStrong: Color(0xFF74897A),
    textPrimary: Color(0xFF14201A),
    textMuted: Color(0xFF566259),
    primary: Color(0xFF111A14),
    onPrimary: Color(0xFFFFFFFF),
    brand: Color(0xFF1B7A3F),
    onBrand: Color(0xFFFFFFFF),
    brandSoft: Color(0xFFE4F1DF),
    brandMid: Color(0xFF6DB36F),
    brandLeaf: Color(0xFFB5CF8A),
    accent: Color(0xFFF0873A),
    onAccent: Color(0xFF111A14),
    accentStrong: Color(0xFFB34A0B),
    accentSoft: Color(0xFFFFEBD9),
    error: Color(0xFFB3261E),
    scrim: Color(0x66111A14),
    statusReceived: StatusStyle(
      fill: Color(0xFFB87800),
      soft: Color(0xFFFFF1D1),
      text: Color(0xFF8A5A00),
    ),
    statusAssigned: StatusStyle(
      fill: Color(0xFF2F6FDE),
      soft: Color(0xFFE3EDFF),
      text: Color(0xFF1D4FB8),
    ),
    statusResolved: StatusStyle(
      fill: Color(0xFF1E8E5A),
      soft: Color(0xFFDDF3E4),
      text: Color(0xFF146B3A),
    ),
    statusEscalated: StatusStyle(
      fill: Color(0xFFD93025),
      soft: Color(0xFFFDE3E0),
      text: Color(0xFFB3261E),
    ),
  );

  static const dark = AppColors(
    background: Color(0xFF0E1612),
    surface: Color(0xFF16221B),
    surfaceMuted: Color(0xFF1E2D24),
    border: Color(0xFF2A3B31),
    borderStrong: Color(0xFF5F7A68),
    textPrimary: Color(0xFFEAF2E6),
    textMuted: Color(0xFF9DB0A2),
    primary: Color(0xFFF2F7EE),
    onPrimary: Color(0xFF0E1612),
    brand: Color(0xFF6DB36F),
    onBrand: Color(0xFF0E1612),
    brandSoft: Color(0xFF1F3A2A),
    brandMid: Color(0xFF6DB36F),
    brandLeaf: Color(0xFFB5CF8A),
    accent: Color(0xFFF0873A),
    onAccent: Color(0xFF111A14),
    accentStrong: Color(0xFFF5A15F),
    accentSoft: Color(0xFF3A2414),
    error: Color(0xFFFF9B91),
    scrim: Color(0x99000000),
    statusReceived: StatusStyle(
      fill: Color(0xFFF2A100),
      soft: Color(0xFF3A2E0E),
      text: Color(0xFFF7C85A),
    ),
    statusAssigned: StatusStyle(
      fill: Color(0xFF5B8FF0),
      soft: Color(0xFF1B2B4D),
      text: Color(0xFF8DB4FF),
    ),
    statusResolved: StatusStyle(
      fill: Color(0xFF3FB27A),
      soft: Color(0xFF17382A),
      text: Color(0xFF7ED6A1),
    ),
    statusEscalated: StatusStyle(
      fill: Color(0xFFF2685D),
      soft: Color(0xFF43201C),
      text: Color(0xFFFF9B91),
    ),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      other is AppColors ? (t < 0.5 ? this : other) : this;
}

extension AppColorsX on BuildContext {
  // Bare MaterialApp tests pump screens without the theme extension; a
  // fallback keeps them renderable instead of crashing on the bang.
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}