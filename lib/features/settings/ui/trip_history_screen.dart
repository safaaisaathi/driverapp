/// D-Trip History — the archive of the shift van's past trips
/// (wireframe WF-22): rows grouped Today / Yesterday / date, each with
/// the wards l10n "n of m" line, the duration, and a status chip
/// (Completed green soft / Partly done amber soft / Running).
///
/// Read-only: trips are created by the shift flow — this screen never
/// writes (0.2 carries no history writer). Reads go through the
/// repositories; no new backend surface.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_localizations.dart';
import '../../../core/models/models.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../features/live_route/domain/ward_steps.dart'
    show tripWardScope;
import '../settings_flow.dart';

/// Status-chip color tokens (0.5`: `statusResolved` green, `statusReceived`
/// amber). Dark variants read at equal contrast from the same tokens.
const Color _chipDone = AppTheme.colorStatusResolved;
const Color _chipPartly = AppTheme.colorStatusReceived;

class TripHistoryScreen extends ConsumerWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final trips = ref.watch(tripHistoryProvider);

    return Scaffold(
      body: SafeArea(
        child: trips.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Text(
              l10n.error,
              key: const Key('tripHistory.error'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            children: [
              Align(
                alignment: AlignmentDirectional.topStart,
                child: AppIconButton(
                  key: const Key('tripHistory.back'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icons.arrow_back,
                  size: 48,
                  semanticsLabel:
                      MaterialLocalizations.of(context).backButtonTooltip,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.tripHistoryTitle,
                key: const Key('tripHistory.title'),
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 24),
              if (data.isEmpty)
                const _HistoryEmpty()
              else
                for (final (index, trip) in data.indexed) ...[
                  _TripRow(trip: trip),
                  if (index != data.length - 1) const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TripRow extends ConsumerWidget {
  final Trip trip;

  const _TripRow({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final routeAsync =
        ref.watch(tripRouteProvider(trip.routeId)).value;
    // The ward TOTAL follows the trip's scope (0.16, ticket-7 review
    // ruling): the history row counts the driver's allotted wards, not the
    // whole route. Pre-0.16 trips fall back to the route's count.
    final totalWards =
        tripWardScope(trip)?.length ?? routeAsync?.wardIds.length ?? 0;
    final done = trip.wardsDone.length;

    // Chip state: running when not yet ended; complete when every route
    // ward ticked (total > 0 — with zero ward data it stays partly-done
    // rather than lying with a complete tick).
    final (String chipLabel, Color chipColor, IconData chipIcon) = switch (trip) {
      _ when trip.endedAt == null => (
          l10n.tripActive,
          _chipPartly,
          Icons.route
        ),
      _ when done >= totalWards && totalWards > 0 => (
          l10n.chipCompleted,
          _chipDone,
          Icons.check_circle
        ),
      _ => (l10n.chipPartlyDone, _chipPartly, Icons.assignment_late),
    };

    // Duration from startedAt → endedAt (or now, for a running trip).
    final duration = trip.endedAt != null
        ? trip.endedAt!.difference(trip.startedAt)
        : DateTime.now().difference(trip.startedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _dayLabel(context, trip),
                  key: const Key('tripHistory.rowLabel'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Icon(chipIcon, size: 14, color: chipColor),
                    Text(
                      chipLabel,
                      key: const Key('tripHistory.rowChip'),
                      style:
                          Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: chipColor,
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            '${l10n.wardsDoneOf(done, totalWards)}'
            ' · ${l10n.hoursMinutes(hours, minutes)}',
            key: const Key('tripHistory.rowMeta'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _dayLabel(BuildContext context, Trip trip) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(trip.date.year, trip.date.month, trip.date.day);
    if (day == today) return l10n.tripToday;
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.tripYesterday;
    }
    return material.formatMediumDate(DateTime(day.year, day.month, day.day));
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.huge),
      child: Column(
        children: [
          // Neutral icon in a `brandSoft` circle (DESIGN-driver-app.md
          // §4.16, CL-D15, removed-T8): tokens only, no mascot.
          Container(
            width: AppSize.permissionIconCircle,
            height: AppSize.permissionIconCircle,
            decoration: BoxDecoration(
              color: c.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.history, size: AppSize.icon * 2, color: c.brand),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(
            l10n.tripHistoryEmpty,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            l10n.tripHistoryEmptyBody,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
