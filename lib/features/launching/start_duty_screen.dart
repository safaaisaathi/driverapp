/// Start Duty — the pre-flight card between Welcome and the route (static).
///
/// Shows what the driver is walking into TODAY (duty card, local only) and
/// hands over to the van-picker / map flow, where the data-backed skeletons
/// and error states take over. Deliberately NOT wired to Firestore yet —
/// the connect point lives one screen deeper (ticket 04/06 flow).
///
/// DESIGN.md §9.8 (inferred): ContourCard duty card, primary CTA pill,
/// language toggle top-end. Fade+slide transition from Welcome (dur.base 200ms).
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/contour_card.dart';
import '../shift_start/ui/language_toggle.dart';
import '../shift_start/ui/shift_start_screen.dart';

class StartDutyScreen extends StatelessWidget {
  const StartDutyScreen({super.key, this.onDutyStarted});

  /// Navigation seam for tests.
  final void Function(BuildContext context)? onDutyStarted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Language toggle top-end (CL-22)
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.page),
                child: Center(
                  child: ContourCard(
                    seed: 'duty-card'.hashCode,
                    lines: 5,
                    minHeight: 220,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dutyTitle,
                          style: context.text.headline.copyWith(color: c.onBrand),
                        ),
                        const SizedBox(height: AppSpace.sm),
                        Text(
                          l10n.dutySubtitle,
                          style: context.text.body.copyWith(
                            color: c.onBrand.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Primary CTA pill (CL-07, CL-08)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.page, 0, AppSpace.page, AppSpace.xxl,
              ),
              child: FilledButton(
                key: const ValueKey('duty-start-button'),
                onPressed: () {
                  if (onDutyStarted != null) {
                    onDutyStarted!(context);
                  } else {
                    Navigator.of(context).pushReplacement(
                      PageRouteBuilder<void>(
                        pageBuilder: (_, __, ___) => const ShiftStartScreen(),
                        transitionsBuilder: (_, animation, __, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                        transitionDuration: const Duration(milliseconds: 200),
                      ),
                    );
                  }
                },
                child: Text(l10n.startDuty),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
