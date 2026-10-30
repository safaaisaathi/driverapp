/// Welcome — the front door after the splash and the start of the ONE-TIME
/// SETUP (fresh-device onboarding, PRD-2 §0.16).
///
/// One message, one CTA, and the language toggle so the layout choice
/// (D1 rule) is available before anything else in the flow. The CTA runs
/// the existing 4-stage permission flow (rationale screens + gateway, 0.13
/// order); the flow stops at the first non-grant and the setup COMPLETES
/// regardless: the setup-done flag lands on the identity controller and
/// the start-shift page (CodeStartScreen) replaces this screen. A denied
/// device stays fully usable — D2's degraded-mode surfacing covers it.
/// Binny is removed from this screen (D-105, removed-T8; the splash Binny
/// is ticket 8).
///
/// DESIGN.md §9.2 (inferred): display title, body, primary CTA pill,
/// language toggle top-end, no mascot. Fade+slide transition from Splash
/// (dur.base 200ms).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/identity/driver_identity_controller.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../shift_start/ui/code_start_screen.dart';
import '../tracking/tracking_providers.dart'
    show trackingPermissionGatewayProvider;
import '../tracking/ui/ui_permission_flow.dart'
    show UIPermissionFlowController;
import '../shift_start/ui/language_toggle.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key, this.onWelcomeDone});

  /// Navigation seam for tests: what replaces this screen AFTER the setup
  /// completes. The setup itself always runs.
  final void Function(BuildContext context)? onWelcomeDone;

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  /// Re-entry guard: the CTA is busy while the permission flow runs (the
  /// CodeStartScreen CTA-bar busy idiom).
  bool _running = false;

  Future<void> _beginSetup() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      final gateway = ref.read(trackingPermissionGatewayProvider);
      await UIPermissionFlowController(gateway, context).requestAll();
      // The flow stopped at the first non-grant (or granted all): either
      // way the one-time setup is complete (0.16 — the app must remain
      // fully usable when permissions are denied).
      await ref.read(driverIdentityControllerProvider.notifier).markSetupDone();
    } finally {
      if (mounted) setState(() => _running = false);
    }
    if (!mounted) return;
    if (widget.onWelcomeDone != null) {
      widget.onWelcomeDone!(context);
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const CodeStartScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language toggle top-end (CL-22: reachable in 1 tap)
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppSpace.page,
                  top: AppSpace.xs,
                ),
                child: const LanguageToggleButton(),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(AppSpace.page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.welcomeTitle,
                    style: context.text.display.copyWith(color: c.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    l10n.welcomeBody,
                    style: context.text.body.copyWith(color: c.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Primary CTA pill (CL-07, CL-08): starts the one-time setup.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page, 0, AppSpace.page, AppSpace.xxl,
              ),
              child: FilledButton(
                key: const ValueKey('welcome-begin-button'),
                onPressed: _running ? null : _beginSetup,
                child: Text(l10n.welcomeCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
