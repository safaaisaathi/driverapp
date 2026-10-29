/// Permission Prompt Screen (DESIGN.md §4.19).
///
/// Shows a rationale before each system permission dialog. The driver sees
/// WHY the permission is needed, then taps "Allow" to trigger the system
/// dialog, or "Not now" to skip with a clear state. Denied state shows an
/// info card with "Open settings".
///
/// M3 shell: round close button top-left, 96dp icon circle, headline title,
/// body explanation, primary "Allow", text "Not now".
library;

import 'package:flutter/material.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_colors.dart';
import 'package:driverapp/core/theme/app_text.dart';
import 'package:driverapp/core/theme/app_tokens.dart';
import 'package:driverapp/core/widgets/app_icon_button.dart';

/// The permission stage being prompted for.
enum PermissionPromptStage {
  locationWhileInUse,
  locationBackground,
  notifications,
  batteryOptimization,
}

/// Shows the permission prompt screen for a specific stage.
///
/// Returns `true` if the driver tapped "Allow", `false` for "Not now"
/// or if the screen was dismissed.
Future<bool> showPermissionPrompt({
  required BuildContext context,
  required PermissionPromptStage stage,
}) async {
  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => _PermissionPromptScreen(stage: stage),
      fullscreenDialog: true,
    ),
  );
  return result ?? false;
}

class _PermissionPromptScreen extends StatelessWidget {
  final PermissionPromptStage stage;

  const _PermissionPromptScreen({required this.stage});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    final (icon, title, body) = _contentForStage(stage, l10n);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Round close button top-left (M3 shell)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.md),
                child: AppIconButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  icon: Icons.close,
                  size: 48,
                  semanticsLabel: MaterialLocalizations.of(context)
                      .closeButtonTooltip,
                ),
              ),
            ),
            const Spacer(),
            // 96dp brandSoft circle with relevant icon
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: c.brandSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: c.brand),
              ),
            ),
            const SizedBox(height: AppSpace.xl),
            // Headline title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Text(
                title,
                style: context.text.headline.copyWith(color: c.textPrimary),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpace.md),
            // Body explanation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.page),
              child: Text(
                body,
                style: context.text.body.copyWith(color: c.textMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            // Primary "Allow" button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                0,
                AppSpace.page,
                AppSpace.lg,
              ),
              child: FilledButton(
                key: ValueKey('permissionAllow_${stage.name}'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.permissionAllow),
              ),
            ),
            // Text "Not now" button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page,
                0,
                AppSpace.page,
                AppSpace.xxl,
              ),
              child: TextButton(
                key: ValueKey('permissionNotNow_${stage.name}'),
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.permissionNotNow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, String, String) _contentForStage(
    PermissionPromptStage stage,
    AppLocalizations l10n,
  ) {
    return switch (stage) {
      PermissionPromptStage.locationWhileInUse => (
          Icons.location_on,
          l10n.trackingPermissionLocationTitle,
          l10n.trackingPermissionWhileInUseClaim,
        ),
      PermissionPromptStage.locationBackground => (
          Icons.location_on,
          l10n.trackingPermissionBackgroundTitle,
          l10n.trackingPermissionBackgroundClaim,
        ),
      PermissionPromptStage.notifications => (
          Icons.notifications,
          l10n.trackingPermissionNotificationsTitle,
          l10n.trackingPermissionNotificationsClaim,
        ),
      PermissionPromptStage.batteryOptimization => (
          Icons.battery_charging_full,
          l10n.trackingPermissionBatteryTitle,
          l10n.trackingPermissionBatteryClaim,
        ),
    };
  }
}