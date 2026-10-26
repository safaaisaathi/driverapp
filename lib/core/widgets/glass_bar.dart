import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// GlassBar — translucent top bar on M1 (Map shell)
/// DESIGN.md Section 3.3 / 4.6
/// Height 64, inset 16 from safe top and sides, radius pill, glass fill, elev2
/// Contents: round 48 icon slot + two-line text + round icon buttons at right
class GlassBar extends StatelessWidget {
  const GlassBar({
    super.key,
    this.leadingIcon,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.showLanguageToggle = false,
    this.currentLocale = 'en',
    this.onLanguageToggle,
  });

  final IconData? leadingIcon;
  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showLanguageToggle;
  final String currentLocale;
  final VoidCallback? onLanguageToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.sm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: AppSize.glassBarHeight,
              decoration: BoxDecoration(
                color: c.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                boxShadow: isDark ? AppElevation.elev2Dark : AppElevation.elev2,
              ),
              child: Row(
                children: [
                  // Leading icon slot
                  if (leadingIcon != null) ...[
                    SizedBox(width: AppSpace.sm),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: c.brandSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(leadingIcon, size: AppSize.icon, color: c.brand, weight: 300),
                      ),
                    ),
                    SizedBox(width: AppSpace.md),
                  ],
                  // Title + subtitle
                  if (title != null || subtitle != null) ...[
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title != null)
                            Text(
                              title!,
                              style: t.titleSmall.copyWith(color: c.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (subtitle != null)
                            Text(
                              subtitle!,
                              style: t.bodySmall.copyWith(color: c.textMuted),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                  // Actions (right side)
                  ...actions,
                  // Language toggle (segmented control)
                  if (showLanguageToggle) ...[
                    SizedBox(width: AppSpace.sm),
                    _LanguageToggle(
                      currentLocale: currentLocale,
                      onToggle: onLanguageToggle,
                    ),
                  ],
                  SizedBox(width: AppSpace.xs),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({
    required this.currentLocale,
    this.onToggle,
  });

  final String currentLocale;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isGu = currentLocale == 'gu';

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tapping the already-selected segment does nothing — the toggle
          // must only switch En <-> Gu (never no-op-reset the selection).
          _LangSegment(
            label: 'ગુ',
            isSelected: isGu,
            onTap: isGu ? null : onToggle,
          ),
          _LangSegment(
            label: 'EN',
            isSelected: !isGu,
            onTap: isGu ? onToggle : null,
          ),
        ],
      ),
    );
  }
}

class _LangSegment extends StatelessWidget {
  const _LangSegment({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? c.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: t.label.copyWith(color: isSelected ? c.onPrimary : c.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// TrackingBadge — pill in glass bar: 8dp brand dot + label
/// DESIGN.md Section 4.17. The label is passed in (CL-21: all strings come
/// from the caller's l10n — this widget owns no copy).
class TrackingBadge extends StatelessWidget {
  const TrackingBadge({
    super.key,
    required this.label,
    this.isActive = true,
  });

  final String label;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: c.brandSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isActive ? c.brand : c.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSpace.xs),
          Text(label, style: t.label.copyWith(color: c.brand)),
        ],
      ),
    );
  }
}