/// Theme built from the shared contract design tokens — PRD-2 section 0.5.
///
/// Widget code never hardcodes colours, sizes or fonts; it uses the tokens
/// here. When `docs/DESIGN.md` is applied later, only this file changes;
/// the token names stay identical (contract 0.12).
library;

import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // -- color tokens (0.5) --
  static const Color colorPrimary = Color(0xFF1E8E5A);
  static const Color colorOnPrimary = Color(0xFFFFFFFF);
  static const Color colorBackground = Color(0xFFF6F8F7);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF1B1F1D);
  static const Color colorTextMuted = Color(0xFF5F6B66);

  // -- status color tokens (0.5) --
  static const Color colorStatusReceived = Color(0xFFF2A100);
  static const Color colorStatusAssigned = Color(0xFF2F6FDE);
  static const Color colorStatusResolved = Color(0xFF1E8E5A);
  static const Color colorStatusEscalated = Color(0xFFD93025);

  // -- shape & spacing tokens (0.5) --
  static const double radiusMd = 12;
  static const double spacingUnit = 8;

  static const String fontFamily = 'NotoSans';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: colorPrimary,
      primary: colorPrimary,
      onPrimary: colorOnPrimary,
      surface: colorSurface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: colorBackground,
      fontFamily: fontFamily,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: colorTextPrimary),
        bodyMedium: TextStyle(color: colorTextPrimary),
        bodySmall: TextStyle(color: colorTextMuted),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: colorPrimary,
        foregroundColor: colorOnPrimary,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? colorPrimary : null,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorPrimary,
          foregroundColor: colorOnPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          minimumSize: const Size(0, 56), // contract section 6: >= 56 dp
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorTextPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          minimumSize: const Size(0, 56),
        ),
      ),
    );
  }
}
