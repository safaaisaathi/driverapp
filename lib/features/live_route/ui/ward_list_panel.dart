/// The ordered ward list panel for the Live Route screen (PRD-2 F-D3:
/// "D2 shows routes.wardIds in order with names; the next ward is
/// highlighted"). Overlays the bottom of the map, thumb-reachable, every row
/// ≥ 56dp (contract section 6).
///
/// Mark Ward Done (the button ticket 07 wires) is NOT here — the list is the
/// D2 shell's route-progress view.
library;

import 'package:flutter/material.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_theme.dart';

import '../domain/ward_steps.dart';

class WardListPanel extends StatelessWidget {
  final String routeName;

  final List<WardStep> wardSteps;

  /// Minutes since the van doc's `lastLocation.updatedAt`; non-null only when
  /// the fix is stale — renders the "last seen X min ago" caption (0.13,
  /// ruling 6: floored, clamped ≥ 0).
  final int? staleMinutes;

  /// True when the offline seam reports offline: cached list keeps showing
  /// with a note (Firestore persistence, F-D7).
  final bool isOffline;

  const WardListPanel({
    super.key,
    required this.routeName,
    required this.wardSteps,
    required this.staleMinutes,
    required this.isOffline,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final done = wardSteps.where((step) => step.isDone).length;

    return Material(
      color: AppTheme.colorSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusMd),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              '$routeName · ${l10n.routeProgress(done, wardSteps.length)}',
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: AppTheme.colorTextPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          if (staleMinutes != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                key: const Key('liveRoute.staleCaption'),
                spacing: 4,
                children: [
                  Icon(Icons.schedule,
                      size: 16, color: AppTheme.colorTextMuted),
                  Text(
                    l10n.vanLastSeen(staleMinutes!),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: AppTheme.colorTextMuted),
                  ),
                ],
              ),
            ),
          if (isOffline)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                key: const Key('liveRoute.offlineNote'),
                spacing: 4,
                children: [
                  Icon(Icons.cloud_off,
                      size: 16, color: AppTheme.colorTextMuted),
                  Text(
                    l10n.offlineShowingCached,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .copyWith(color: AppTheme.colorTextMuted),
                  ),
                ],
              ),
            ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.40,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: wardSteps.length,
              itemBuilder: (context, index) =>
                  _WardRow(step: wardSteps[index]),
            ),
          ),
        ],
      ),
    );
  }
}

class _WardRow extends StatelessWidget {
  final WardStep step;

  const _WardRow({required this.step});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final highlighted = step.isNext;

    return Container(
      key: Key('liveRoute.wardRow.${step.ward.id}'),
      color: highlighted
          ? AppTheme.colorPrimary.withValues(alpha: 0.10)
          : null,
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 12,
        children: [
          // Order badge — the visiting order despite sorting/filtering chips.
          _OrderBadge(isDone: step.isDone, isNext: highlighted, index: step.orderIndex),
          Expanded(
            child: Text(
              step.ward.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontWeight: highlighted ? FontWeight.bold : null,
                    color: AppTheme.colorTextPrimary,
                  ),
            ),
          ),
          if (step.isNext)
            Container(
              key: const Key('liveRoute.nextChip'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.colorPrimary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.nextWardChip,
                style: const TextStyle(
                  color: AppTheme.colorOnPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (step.isDone)
            Icon(
              Icons.check_circle,
              color: AppTheme.colorPrimary,
              // Not const: the interpolated key depends on the ward id.
              key: Key('liveRoute.doneTick.${step.ward.id}'),
            ),
          if (step.isDone && step.isFlagged)
            Icon(
              Icons.flag,
              size: 18,
              color: AppTheme.colorStatusEscalated,
              key: Key('liveRoute.flagged.${step.ward.id}'),
            ),
        ],
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  final bool isDone;
  final bool isNext;
  final int index;

  const _OrderBadge({
    required this.isDone,
    required this.isNext,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final highlighted = isNext || isDone;
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted
            ? AppTheme.colorPrimary
            : AppTheme.colorBackground,
        border: Border.all(
          color: highlighted ? AppTheme.colorPrimary : AppTheme.colorTextMuted,
        ),
      ),
      child: Text(
        '${index + 1}',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: highlighted
              ? AppTheme.colorOnPrimary
              : AppTheme.colorTextMuted,
        ),
      ),
    );
  }
}
