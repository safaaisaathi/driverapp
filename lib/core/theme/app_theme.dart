import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text.dart';
import 'app_tokens.dart';

/// Theme builder for the Safai Sathi design system.
/// Returns a ThemeData with all design tokens wired.
ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.light ? AppColors.light : AppColors.dark;
  final text = AppTextTheme.of(c);

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.brand,
    onSecondary: c.onBrand,
    tertiary: c.accent,
    onTertiary: c.onAccent,
    error: c.error,
    onError: c.background,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.surfaceMuted,
    outline: c.borderStrong,
    outlineVariant: c.border,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.background,
    extensions: [c, text],
    textTheme: _textTheme(text),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: Size(0, AppSize.buttonDriver),
        shape: const StadiumBorder(),
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        textStyle: text.button,
        padding: EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, AppSize.buttonDriver),
        shape: const StadiumBorder(),
        foregroundColor: c.textPrimary,
        side: BorderSide(color: c.borderStrong, width: 1.5),
        textStyle: text.button,
        padding: EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: Size(0, AppSize.buttonUser),
        foregroundColor: c.brand,
        textStyle: text.button,
        padding: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.borderStrong, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.borderStrong, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.brand, width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c.error, width: 2.5),
      ),
      labelStyle: text.label.copyWith(color: c.textMuted),
      hintStyle: text.body.copyWith(color: c.textMuted),
      errorStyle: text.bodySmall.copyWith(color: c.error),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      modalBarrierColor: c.scrim,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.primary,
      contentTextStyle: text.body.copyWith(color: c.onPrimary),
      shape: const StadiumBorder(),
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: c.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(
      color: c.border,
      thickness: 1,
      space: AppSpace.cardGap,
    ),
    listTileTheme: ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpace.cardPad),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
      tileColor: c.surface,
      titleTextStyle: text.titleSmall,
      subtitleTextStyle: text.bodySmall,
      minLeadingWidth: AppSpace.md,
    ),
    tabBarTheme: TabBarThemeData(
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        color: c.primary,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      labelStyle: text.label.copyWith(color: c.onPrimary),
      unselectedLabelStyle: text.label.copyWith(color: c.textMuted),
      dividerColor: Colors.transparent,
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) return c.primary.withValues(alpha: 0.08);
        return Colors.transparent;
      }),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.primary;
          return c.surfaceMuted;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return c.onPrimary;
          return c.textPrimary;
        }),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        ),
        padding: WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
        ),
        textStyle: WidgetStatePropertyAll(text.label),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return BorderSide(color: c.primary, width: 1.5);
          }
          return BorderSide(color: c.borderStrong, width: 1.5);
        }),
      ),
    ),
  );
}

TextTheme _textTheme(AppTextTheme t) => TextTheme(
  displayLarge: t.display,
  displayMedium: t.headline,
  displaySmall: t.title,
  headlineLarge: t.headline,
  headlineMedium: t.title,
  headlineSmall: t.titleSmall,
  titleLarge: t.title,
  titleMedium: t.titleSmall,
  titleSmall: t.body,
  bodyLarge: t.body,
  bodyMedium: t.bodySmall,
  bodySmall: t.bodySmall,
  labelLarge: t.button,
  labelMedium: t.label,
  labelSmall: t.attribution,
);

// -- Legacy contract tokens (0.5) --
// Kept intact (0.12: token names stay identical) while the DESIGN.md
// migration walks: existing screens read these until each is re-rendered
// with the new context.colors / context.text extensions above.

/// Theme built from the shared contract design tokens — PRD-2 section 0.5.
class AppTheme {
  AppTheme._();

  // -- color tokens (0.5) --
  // Values now follow docs/DESIGN.md (§2.1): names stay identical (0.12),
  // `colorPrimary` is the INK of the primary-CTA pill.
  static const Color colorPrimary = Color(0xFF111A14);
  static const Color colorOnPrimary = Color(0xFFFFFFFF);
  static const Color colorBackground = Color(0xFFF3F6F2);
  static const Color colorSurface = Color(0xFFFFFFFF);
  static const Color colorTextPrimary = Color(0xFF14201A);
  static const Color colorTextMuted = Color(0xFF566259);

  // -- status color tokens (0.5) -- (DESIGN.md §2.1 `.fill` values)
  static const Color colorStatusReceived = Color(0xFFB87800);
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