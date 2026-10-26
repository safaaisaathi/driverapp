/// Welcome — the front door after the splash (static, no data yet).
///
/// One message, one CTA, and the language toggle so the layout choice
/// (D1 rule) is available before anything else in the flow. Connects to
/// NOTHING: the API-facing flow starts after Start Duty is pressed.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_tokens.dart';
import '../shift_start/ui/language_toggle.dart';
import 'start_duty_screen.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, this.onWelcomeDone});

  /// Navigation seam for tests.
  final void Function(BuildContext context)? onWelcomeDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                    style: theme.textTheme.displaySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpace.md),
                  Text(
                    l10n.welcomeBody,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(),
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
                      MaterialPageRoute<void>(
                        builder: (_) => const StartDutyScreen(),
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
