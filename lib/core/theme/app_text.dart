import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles for the Safai Sathi design system.
///
/// Fonts: Noto Sans + Noto Sans Gujarati as VARIABLE fonts, bundled in
/// `assets/fonts/` and declared in pubspec.yaml (DESIGN.md §2.2). Bundling
/// (not runtime google_fonts fetch) is deliberate: the van drives through
/// dead zones — text must never depend on network.
/// Every style is Noto Sans with Gujarati as the fallback family.
/// Every TextStyle sets fontFamily: 'NotoSans' and fontFamilyFallback: ['NotoSansGujarati'].

@immutable
class AppTextTheme extends ThemeExtension<AppTextTheme> {
  const AppTextTheme({
    required this.heroNumber,
    required this.display,
    required this.headline,
    required this.title,
    required this.titleSmall,
    required this.body,
    required this.bodySmall,
    required this.label,
    required this.button,
    required this.attribution,
  });

  final TextStyle heroNumber; // 56 / 60, 400, tabular figures
  final TextStyle display; // 36 / 44, 300
  final TextStyle headline; // 28 / 36, 500
  final TextStyle title; // 20 / 30, 600
  final TextStyle titleSmall; // 16 / 24, 600
  final TextStyle body; // 16 / 24, 400
  final TextStyle bodySmall; // 14 / 22, 400
  final TextStyle label; // 14 / 20, 600
  final TextStyle button; // 16 / 24, 600
  final TextStyle attribution; // 12 / 16, 400

  @override
  AppTextTheme copyWith({
    TextStyle? heroNumber,
    TextStyle? display,
    TextStyle? headline,
    TextStyle? title,
    TextStyle? titleSmall,
    TextStyle? body,
    TextStyle? bodySmall,
    TextStyle? label,
    TextStyle? button,
    TextStyle? attribution,
  }) => AppTextTheme(
    heroNumber: heroNumber ?? this.heroNumber,
    display: display ?? this.display,
    headline: headline ?? this.headline,
    title: title ?? this.title,
    titleSmall: titleSmall ?? this.titleSmall,
    body: body ?? this.body,
    bodySmall: bodySmall ?? this.bodySmall,
    label: label ?? this.label,
    button: button ?? this.button,
    attribution: attribution ?? this.attribution,
  );

  @override
  AppTextTheme lerp(ThemeExtension<AppTextTheme>? other, double t) {
    if (other is! AppTextTheme) return this;
    return AppTextTheme(
      heroNumber: TextStyle.lerp(heroNumber, other.heroNumber, t)!,
      display: TextStyle.lerp(display, other.display, t)!,
      headline: TextStyle.lerp(headline, other.headline, t)!,
      title: TextStyle.lerp(title, other.title, t)!,
      titleSmall: TextStyle.lerp(titleSmall, other.titleSmall, t)!,
      body: TextStyle.lerp(body, other.body, t)!,
      bodySmall: TextStyle.lerp(bodySmall, other.bodySmall, t)!,
      label: TextStyle.lerp(label, other.label, t)!,
      button: TextStyle.lerp(button, other.button, t)!,
      attribution: TextStyle.lerp(attribution, other.attribution, t)!,
    );
  }

  static AppTextTheme of(AppColors c) {
    // One line per weight axis entry declared in pubspec.yaml (variable
    // fonts select the instance through fontWeight).
    TextStyle font(double size, double height, FontWeight weight) =>
        TextStyle(
          fontSize: size,
          height: height / size,
          fontWeight: weight,
          fontFamily: 'NotoSans',
          fontFamilyFallback: const ['NotoSansGujarati'],
        );

    return AppTextTheme(
      heroNumber: font(56, 60, FontWeight.w400).copyWith(
        color: c.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      display: font(36, 44, FontWeight.w300).copyWith(color: c.textPrimary),
      headline: font(28, 36, FontWeight.w500).copyWith(color: c.textPrimary),
      title: font(20, 30, FontWeight.w600).copyWith(color: c.textPrimary),
      titleSmall: font(16, 24, FontWeight.w600).copyWith(color: c.textPrimary),
      body: font(16, 24, FontWeight.w400).copyWith(color: c.textPrimary),
      bodySmall: font(14, 22, FontWeight.w400).copyWith(color: c.textMuted),
      label: font(14, 20, FontWeight.w600).copyWith(color: c.textPrimary),
      button: font(16, 24, FontWeight.w600).copyWith(color: c.textPrimary),
      attribution: font(12, 16, FontWeight.w400).copyWith(color: c.textMuted),
    );
  }
}

extension AppTextX on BuildContext {
  // Fallback mirrors .colors (bare-MaterialApp tests pump without theme).
  AppTextTheme get text =>
      Theme.of(this).extension<AppTextTheme>() ?? AppTextTheme.of(AppColors.light);
}
