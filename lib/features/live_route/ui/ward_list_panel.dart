/// The ordered ward list panel for the Live Route screen (PRD-2 F-D3:
/// "D2 shows routes.wardIds in order with names; the next ward is
/// highlighted"). Overlays the bottom of the map, thumb-reachable, every row
/// ≥ 56dp (contract section 6).
///
/// Mark Ward Done (ticket 07): the NEXT ward's row carries the big ≥56dp
/// button (one-handed, thumb zone); every other UNDONE ward renders a
/// smaller control (out-of-order marks are allowed — grilled decision in the
/// spec's Implementation Decisions, spec story 14). Done rows render their
/// tick (+ flagged icon for admin-review marks, `trips.wardsDone.flagged`).
///
/// Skin re-shelled per docs/DESIGN.md: the route-progress head is the
/// signature ContourCard (rule CL-12) — same strings, same keys, ink text
/// on the brandMid fill.
library;

import 'package:flutter/material.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_colors.dart';
import 'package:driverapp/core/theme/app_text.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/core/widgets/contour_card.dart';

import '../domain/ward_steps.dart';

class WardListPanel extends StatefulWidget {
  final String routeName;

  final List<WardStep> wardSteps;

  /// Minutes since the van doc's `lastLocation.updatedAt`; non-null only when
  /// the fix is stale — renders the "last seen X min ago" caption (0.13,
  /// ruling 6: floored, clamped ≥ 0).
  final int? staleMinutes;

  /// True when the offline seam reports offline: cached list keeps showing
  /// with a note (Firestore persistence, F-D7).
  final bool isOffline;

  /// Marks in flight (`live_route/mark_ward_done_flow.dart`): those rows'
  /// controls disable so one tap cannot double-write.
  final Set<String> markInFlight;

  /// True when the LAST mark write failed — one boring retry line (the
  /// screen's own global error state is NOT used for a failed append).
  final bool markWriteFailed;

  /// False while there is no open trip today: nothing can receive a
  /// `wardsDone` append — controls disable with a one-line hint.
  final bool markEnabled;

  /// The mark event: `wardId` in, the flow handles dedupe/guard/decision.
  final void Function(String wardId) onMark;

  const WardListPanel({
    super.key,
    required this.routeName,
    required this.wardSteps,
    required this.staleMinutes,
    required this.isOffline,
    required this.markInFlight,
    required this.markWriteFailed,
    required this.markEnabled,
    required this.onMark,
  });

  @override
  State<WardListPanel> createState() => _WardListPanelState();
}

class _WardListPanelState extends State<WardListPanel> {
  /// One reused global key on the HIGHLIGHTED row wrapper — the hook used to
  /// keep the next ward's action visible (DESIGN.md law: sheet content is
  /// never covered by the nav at the default snap). Reassigned each build to
  /// whichever row is next; old rows just drop their hold on it.
  final GlobalKey _nextRowKey = GlobalKey();

  /// Ward id the auto-reveal last ran for — guards against re-triggering on
  /// no-change rebuilds (in-flight sets, l10n redraws, stale captions).
  String? _autoRevealedFor;

  String? _nextWardId() {
    for (final step in widget.wardSteps) {
      if (!step.isDone) return step.ward.id;
    }
    return null;
  }

  /// Scrolls the (scrollable) list so the next ward's row is fully above the
  /// nav reserve once its layout is known. A no-op when the row already fits
  /// (Scrollable.ensureVisible leaves fully-visible targets alone).
  void _ensureNextVisible() {
    final wardId = _nextWardId();
    if (wardId == null || wardId == _autoRevealedFor) return;
    _autoRevealedFor = wardId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final context = _nextRowKey.currentContext;
      if (context == null) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      Scrollable.ensureVisible(
        context,
        alignment: 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void didUpdateWidget(WardListPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reveal runs only when the NEXT ward actually changed — a mark moved the
    // highlight, not an in-flight flicker or a caption refresh.
    if (_nextWardId() != _autoRevealedFor) _ensureNextVisible();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = widget;
    final done = w.wardSteps.where((step) => step.isDone).length;
    // On a fresh panel build (first appearance, screen re-entry), line the
    // next ward's action up too — never below the nav reserve.
    _ensureNextVisible();

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
          // Route progress head — the signature ContourCard (CL-12). The
          // composite string stays one Text (tests match widgets by it).
          // No horizontal pad here: the sheet shell already gives the
          // 20 dp page inset — an extra 16 would re-wrap the composite
          // progress string and push the last row behind the nav reserve.
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
            child: ContourCard(
              seed: w.routeName.hashCode,
              minHeight: 56,
              lines: 5,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${w.routeName} · ${l10n.routeProgress(done, w.wardSteps.length)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall.copyWith(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          // Non-lazy scroll: a plain Column inside a SingleChildScrollView
          // builds every row outright (the sheet owns the viewport), so
          // finders and taps on rows below the fold stay stable.
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                if (w.staleMinutes != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Row(
                      key: const Key('liveRoute.staleCaption'),
                      spacing: 4,
                      children: [
                        Icon(Icons.schedule,
                            size: 16, color: AppTheme.colorTextMuted),
                        Text(
                          l10n.vanLastSeen(w.staleMinutes!),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: AppTheme.colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                if (w.isOffline)
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
                if (!w.markEnabled)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      key: const Key('liveRoute.markNoTripHint'),
                      spacing: 4,
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: AppTheme.colorTextMuted),
                        Text(
                          l10n.markWardDoneNoTrip,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: AppTheme.colorTextMuted),
                        ),
                      ],
                    ),
                  ),
                if (w.markWriteFailed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: Row(
                      key: const Key('liveRoute.markError'),
                      spacing: 4,
                      children: [
                        Icon(Icons.error_outline,
                            size: 16, color: AppTheme.colorStatusEscalated),
                        Text(
                          l10n.markWardDoneFailed,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(color: AppTheme.colorStatusEscalated),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                // The rows are regular list children: the sheet owns the
                // viewport height now, so a second internal cap is redundant.
                for (final step in w.wardSteps)
                  _WardRow(
                    step: step,
                    markEnabled: w.markEnabled,
                    markInFlight: w.markInFlight,
                    onMark: w.onMark,
                    nextRowKey: step.isNext ? _nextRowKey : null,
                  ),
              ],
            ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WardRow extends StatelessWidget {
  final WardStep step;

  final bool markEnabled;

  final Set<String> markInFlight;

  final void Function(String wardId) onMark;

  /// Set ONLY on the currently-highlighted row (the panel re-assigns it each
  /// rebuild): the handle the panel auto-reveal uses to keep the next ward's
  /// action above the nav. Also carrying the row's canonical test key.
  final GlobalKey? nextRowKey;

  const _WardRow({
    required this.step,
    required this.markEnabled,
    required this.markInFlight,
    required this.onMark,
    this.nextRowKey,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final highlighted = step.isNext;
    final inFlight = markInFlight.contains(step.ward.id);
    final canMark = !step.isDone && markEnabled && !inFlight;

    // The NEXT ward's row carries the one-tap ≥56dp action (contract
    // section 6, one-handed driver); other undone wards get the smaller
    // out-of-order control; done rows render their record only.
    if (highlighted) {
      return KeyedSubtree(
        key: nextRowKey,
        child: Container(
          key: Key('liveRoute.wardRow.${step.ward.id}'),
        color: AppTheme.colorPrimary.withValues(alpha: 0.10),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 4,
          children: [
            _RowHead(step: step),
            FilledButton(
              key: const Key('liveRoute.markNextWard'),
              onPressed: canMark ? () => onMark(step.ward.id) : null,
              child: Text(
                l10n.markWardDone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      );
    }

    return Container(
      key: Key('liveRoute.wardRow.${step.ward.id}'),
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 12,
        children: [
          Expanded(child: _RowHead(step: step)),
          if (!step.isDone)
            IconButton(
              // The out-of-order control (spec story 14 — real routes
              // rarely follow list order). Keyed per-ward; disabled while
              // no trip can receive the append or a write is in flight.
              key: Key('liveRoute.markWard.${step.ward.id}'),
              tooltip: l10n.markWardDone,
              onPressed: canMark ? () => onMark(step.ward.id) : null,
              icon: const Icon(Icons.check_circle_outline),
              color: AppTheme.colorPrimary,
            ),
          if (step.isDone)
            Icon(
              Icons.check_circle,
              color: step.isFlagged
                  ? AppTheme.colorStatusEscalated
                  : AppTheme.colorPrimary,
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

/// The shared row head: order badge + ward name (+ the Next chip on the
/// highlighted row). A plain Row — the wrapping row lays it out (Expanded
/// in the fixed-height row, stretched in the next-ward column).
class _RowHead extends StatelessWidget {
  final WardStep step;

  const _RowHead({required this.step});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      spacing: 12,
      children: [
        _OrderBadge(isDone: step.isDone, isNext: step.isNext, index: step.orderIndex),
        Expanded(
          child: Text(
            step.ward.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  fontWeight: step.isNext ? FontWeight.bold : null,
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
      ],
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
