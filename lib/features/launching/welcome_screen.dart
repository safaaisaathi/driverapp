/// Welcome — the front door after the splash (static, no data yet).
///
/// One message, one CTA, and the language toggle so the layout choice
/// (D1 rule) is available before anything else in the flow. Connects to
/// NOTHING: the API-facing flow starts after Start Duty is pressed.
///
/// DESIGN.md §9.2 (inferred): Binny wait pose, display title, body,
/// primary CTA pill, language toggle top-end. Fade+slide transition from
/// Splash (dur.base 200ms).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/binny.dart';
import '../shift_start/ui/language_toggle.dart';
import 'start_duty_screen.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, this.onWelcomeDone});

  /// Navigation seam for tests.
  final void Function(BuildContext context)? onWelcomeDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            // Binny wait pose for empty/onboarding (DESIGN.md D-06)
            const BinnyView(pose: BinnyPose.wait, size: 160),
            const SizedBox(height: AppSpace.xl),
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
            // Primary CTA pill (CL-07, CL-08)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page, 0, AppSpace.page, AppSpace.xxl,
              ),
              child: FilledButton(
                key: const ValueKey('welcome-begin-button'),
                onPressed: () {
                  if (onWelcomeDone != null) {
                    onWelcomeDone!(context);
                  } else {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder<void>(
                        pageBuilder: (_, __, ___) => const StartDutyScreen(),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    );
                  }
                },
                child: Text(l10n.welcomeCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
