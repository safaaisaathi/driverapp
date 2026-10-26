import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// AppIconButton — 48dp circle (driver 56dp), glass when floating on map
/// DESIGN.md Section 4.2
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = AppSize.iconButtonDriver,
    this.isGlass = false,
    this.semanticsLabel,
    this.tooltip,
    this.fillColor,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final double size;
  final bool isGlass;
  final String? semanticsLabel;
  final String? tooltip;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;

    final bgColor = fillColor ??
        (isGlass
            ? c.surface.withValues(alpha: 0.82)
            : c.surface);

    final iconColor = c.textPrimary;
    final shadows = isGlass ? (isDark ? AppElevation.elev2Dark : AppElevation.elev2) : AppElevation.elev0;

    Widget button = Material(
      color: bgColor,
      shape: const CircleBorder(),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        customBorder: const CircleBorder(),
        splashColor: iconColor.withValues(alpha: 0.08),
        highlightColor: iconColor.withValues(alpha: 0.04),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: shadows,
          ),
          child: Center(
            child: Icon(icon, size: AppSize.icon, color: iconColor, weight: 300),
          ),
        ),
      ),
    );

    if (!enabled) {
      button = Opacity(opacity: 0.4, child: button);
    }

    if (semanticsLabel != null) {
      button = Semantics(
        label: semanticsLabel,
        button: true,
        enabled: enabled,
        child: button,
      );
    }

    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }

    return button;
  }
}