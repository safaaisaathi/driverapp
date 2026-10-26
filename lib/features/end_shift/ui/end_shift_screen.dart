/// D5 End Shift (ticket 08) — the M3 Flow shell (docs/DESIGN.md §3.2 /
/// §770 / §9.10): round close button top-left, the shift summary in the
/// signature ContourCard (CL-12: shift summary), ONE primary "End Shift"
/// pill pinned bottom inside a CTA bar, and — after the confirm — the
/// success state with Binny `sleep` + "Shift ended" (CL-15).
///
/// The screen writes ONLY through the flow controller
/// (`end_shift_flow.dart`); no direct repository calls from the UI.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_colors.dart';
import 'package:driverapp/core/theme/app_text.dart';
import 'package:driverapp/core/theme/app_tokens.dart';
import 'package:driverapp/core/widgets/app_icon_button.dart';
import 'package:driverapp/core/widgets/binny.dart';
import 'package:driverapp/core/widgets/contour_card.dart';
import 'package:driverapp/features/live_route/live_route_providers.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';

import '../domain/end_shift_flow.dart';

class EndShiftScreen extends ConsumerWidget {
  const EndShiftScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final phase = ref.watch(endShiftFlowProvider);
    final session = ref.watch(shiftControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Main body.
            Positioned.fill(
              child: switch (phase) {
                EndShiftPhase.ended => _EndedState(
                    message: l10n.shiftEnded,
                  ),
                _ => _SummaryBody(phase: phase, session: session),
              },
            ),

            // M3 round close/back button, top-left.
            Positioned(
              top: AppSpace.md,
              left: AppSpace.md,
              child: ExcludeSemantics(
                child: AppIconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icons.close,
                  size: 48,
                  isGlass: true,
                  semanticsLabel: MaterialLocalizations.of(context)
                      .closeButtonTooltip,
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-confirm body: the ContourCard summary (wards done, duration), and
/// the "End Shift" primary in a pinned CTA bar.
class _SummaryBody extends ConsumerWidget {
  final EndShiftPhase phase;
  final ShiftSession? session;

  const _SummaryBody({required this.phase, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;
    final trip = ref.watch(openTripProvider).value;
    final total =
        ref.watch(routeModelProvider).value?.wardIds.length ?? trip?.wardsDone.length ?? 0;
    final done = trip?.wardsDone.length ?? 0;
    final mins = session?.startedAt == null
        ? null
        : DateTime.now().difference(session!.startedAt).inMinutes.floor().clamp(0, 10 * 60 * 24);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.page,
        AppSpace.xxl + AppSpace.xxxl,
        AppSpace.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.lg,
        children: [
          ContourCard(
            seed: session?.routeId.hashCode ?? 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.xs,
              children: [
                Text('$done', style: context.text.heroNumber),
                Text(
                  l10n.routeProgress(done, total),
                  style: context.text.bodySmall.copyWith(color: c.textPrimary),
                ),
                if (mins != null)
                  Text(
                    l10n.endShiftDuration(mins),
                    style: context.text.bodySmall.copyWith(color: c.textPrimary),
                  ),
              ],
            ),
          ),
          if (phase == EndShiftPhase.failed)
            Row(
              spacing: AppSpace.sm,
              children: [
                Icon(Icons.error_outline,
                    size: AppSize.iconSmall, color: c.statusEscalated.text),
                Expanded(
                  child: Text(
                    l10n.endShiftFailed,
                    style: context.text.bodySmall
                        .copyWith(color: c.statusEscalated.text),
                  ),
                ),
              ],
            ),
          const Spacer(),
          // CTA bar: 16 dp bottom + safe area, one ink pill 64 (driver).
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.lg),
            child: SizedBox(
              height: AppSize.buttonDriver,
              child: FilledButton(
                onPressed: phase == EndShiftPhase.ending
                    ? null
                    : () =>
                        ref.read(endShiftFlowProvider.notifier).confirmEnd(),
                child: Text(
                  l10n.endShiftPrimary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Post-confirm success state (Binny sleep — CL-15).
class _EndedState extends StatelessWidget {
  final String message;

  const _EndedState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.lg,
        children: [
          ExcludeSemantics(
            child: BinnyView(pose: BinnyPose.sleep),
          ),
          Text(message, style: context.text.headline),
        ],
      ),
    );
  }
}
