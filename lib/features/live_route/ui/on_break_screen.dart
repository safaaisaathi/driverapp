/// D-On break (wireframe WF-25): a locally-paused shift. `van.status` is
/// NOT written (contract: idle|on_shift|offline only) — this is a
/// driver-facing pause shown on screen. Read/resume through [BreakController].
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../domain/break_flow.dart';

/// On break screen. Shows the elapsed break time and a Resume button.
class OnBreakScreen extends ConsumerWidget {
  const OnBreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final c = Theme.of(context).colorScheme;
    final breakState = ref.watch(breakControllerProvider);
    final elapsed = breakState.elapsed;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: AlignmentDirectional.topStart,
              child: AppIconButton(
                key: const Key('onBreak.back'),
                onPressed: () => Navigator.of(context).pop(),
                icon: Icons.arrow_back,
                size: 48,
                semanticsLabel: MaterialLocalizations.of(context)
                    .backButtonTooltip,
              ),
            ),
            const SizedBox(height: AppTheme.spacingUnit),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.onBreakTitle,
                    key: const Key('onBreak.title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppTheme.spacingUnit),
                  Text(
                    l10n.onBreakBody,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingUnit * 3),
                  // Elapsed break timer.
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.pause, size: 20),
                        const SizedBox(width: AppSpace.sm),
                        Text(
                          _format(elapsed),
                          key: const Key('onBreak.timer'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('onBreak.resume'),
                  onPressed: () {
                    ref.read(breakControllerProvider.notifier).end();
                    Navigator.of(context).pop();
                  },
                  child: Text(l10n.onBreakResume),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
