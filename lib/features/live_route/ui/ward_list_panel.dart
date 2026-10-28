/// The ordered ward list panel for the Live Route screen (PRD-2 F-D3:
/// "D2 shows routes.wardIds in order with names; the next ward is
/// highlighted").
///
/// Plain content — the sheet shell (`core/widgets/draggable_sheet.dart`)
/// owns the single scroll viewport, so nothing in here scrolls (DESIGN.md
/// §4.11: never nest scrolling). Content order per §4.11: the route-progress
/// ContourCard head → the ONE primary action (§4.17 BigActionButton, one per
/// screen) → the ward rows. While any ward is undone that primary is the
/// Mark control; once EVERY ward is done it becomes the End Shift entry
/// (the old end-trip banner on the map is gone — device UX pass 2026-10-28).
///
/// Rows are 72 dp cards (§4.17): a 48 dp leading circle carries the state —
/// `primary` + number for the next ward, `brand` + check for a done ward,
/// `surface` + number for a pending one — with the ward name, and on the
/// right either the out-of-order mark control (undone, spec story 14) or the
/// done record (check + the word "Done", + the flagged icon for
/// admin-review marks, `trips.wardsDone.flagged`).
///
/// The old auto-reveal machinery (Scrollable.ensureVisible on the next row)
/// is gone: the action is pinned right under the head, so nothing can be
/// "hidden below the nav" in the first place.
library;

import 'package:flutter/material.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_colors.dart';
import 'package:driverapp/core/theme/app_text.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/core/theme/app_tokens.dart';
import 'package:driverapp/core/widgets/contour_card.dart';

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

  /// Pushes the D5 end-shift summary. Rendered as the sheet's ONE primary
  /// once every ward is done — replacing the mark control (the old
  /// end-trip banner on the map is gone, device UX pass 2026-10-28).
  final VoidCallback onEndShift;

  /// The live sheet controller — drives the head card's affordance arrow
  /// (flips from up to down once the sheet reaches its full snap). Null in
  /// previews/tests that don't own a sheet: the arrow renders static.
  final DraggableScrollableController? sheetController;

  /// The sheet's full snap fraction — what "completely extended" means.
  final double sheetFullFraction;

  /// The head card's top padding — the sheet-local gap between the grab
  /// strip and the card's top edge. The live route adds it to
  /// [DraggableSheet.grabStripHeight] when it derives the collapsed fraction:
  /// card top must land exactly on the pill nav's top edge.
  static const double headTopPadding = AppSpace.sm;

  /// The head card's height — exactly the PillNav pill's height (80 dp), so
  /// a card whose top sits on the pill's top is masked 1:1 by the pill.
  static const double headCardHeight = AppSize.navHeightDriver;

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
    required this.onEndShift,
    this.sheetController,
    this.sheetFullFraction = 0.96,
  });

  WardStep? get _next {
    for (final step in wardSteps) {
      if (!step.isDone) return step;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final w = this;
    final c = context.colors;
    final done = w.wardSteps.where((step) => step.isDone).length;
    final next = _next;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.cardGap,
      children: [
        // Route progress head — the signature ContourCard (CL-12/13). Sized
        // EXACTLY like the PillNav pill (80 dp, pill radius, same 16 dp
        // inset) so the collapsed sheet stacks it flush on the nav and the
        // two read as ONE unit (device pass 2026-10-28). The composite
        // string stays one Text (tests match widgets by it); ink text only
        // on the brandMid fill (CL-14); the affordance arrow flips at full.
        Padding(
          padding: const EdgeInsets.only(top: WardListPanel.headTopPadding),
          child: ContourCard(
            seed: w.routeName.hashCode,
            minHeight: WardListPanel.headCardHeight,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: Center(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${w.routeName} · ${l10n.routeProgress(done, w.wardSteps.length)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall.copyWith(
                        color: AppTheme.colorPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  _SheetArrow(
                    controller: w.sheetController,
                    fullFraction: w.sheetFullFraction,
                  ),
                ],
              ),
            ),
          ),
        ),

        // THE primary action of the screen (§4.17 BigActionButton: 72 dp,
        // full width, pill, one per screen). Pinned right after the head so
        // it is reachable at every snap without hunting for a row. Route
        // complete swaps it for the End Shift entry (ticket 08) — same slot,
        // still the screen's one primary.
        if (next != null)
          _MarkNextButton(
            next: next,
            enabled: w.markEnabled && !w.markInFlight.contains(next.ward.id),
            onMark: w.onMark,
          )
        else if (w.wardSteps.isNotEmpty)
          FilledButton(
            key: const Key('liveRoute.endShift'),
            onPressed: w.onEndShift,
            style: FilledButton.styleFrom(
              // Lesson (glossary 2026-10-26): never Size.fromHeight — width=∞
              // crashes Rows. Size(0, h) keeps the pill free to stretch.
              minimumSize: const Size(0, AppSize.bigAction),
            ),
            child: Text(
              l10n.endShiftPrimary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // One-line captions: stale fix, offline cache note, the no-trip
        // guard, and the failed-write retry line.
        if (w.staleMinutes != null)
          _Caption(
            key: const Key('liveRoute.staleCaption'),
            icon: Icons.schedule,
            text: l10n.vanLastSeen(w.staleMinutes!),
          ),
        if (w.isOffline)
          _Caption(
            key: const Key('liveRoute.offlineNote'),
            icon: Icons.cloud_off,
            text: l10n.offlineShowingCached,
          ),
        if (!w.markEnabled)
          _Caption(
            key: const Key('liveRoute.markNoTripHint'),
            icon: Icons.info_outline,
            text: l10n.markWardDoneNoTrip,
          ),
        if (w.markWriteFailed)
          _Caption(
            key: const Key('liveRoute.markError'),
            icon: Icons.error_outline,
            text: l10n.markWardDoneFailed,
            color: c.statusEscalated.fill,
          ),

        // The 72 dp ward cards (§4.17).
        for (final step in w.wardSteps)
          _WardRow(
            step: step,
            markEnabled: w.markEnabled,
            markInFlight: w.markInFlight,
            onMark: w.onMark,
          ),
      ],
    );
  }
}

/// §4.17 BigActionButton: height 72, full width, pill, `primary`, leading
/// status icon 28. The semantic label names the ward it marks — the visible
/// label stays the canonical "Mark Ward Done".
class _MarkNextButton extends StatelessWidget {
  final WardStep next;
  final bool enabled;
  final void Function(String wardId) onMark;

  const _MarkNextButton({
    required this.next,
    required this.enabled,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Plain FilledButton — the canonical one-primary shape. (A
    // Semantics(container:) or Tooltip wrapper here replaced the button's
    // render object between the widget tests' finder evaluation and their
    // hit test — taps "missed"; bisecting kept the bare button.)
    return FilledButton(
      key: const Key('liveRoute.markNextWard'),
      onPressed: enabled ? () => onMark(next.ward.id) : null,
      style: FilledButton.styleFrom(
        // Lesson (glossary 2026-10-26): never Size.fromHeight — width=∞
        // crashes Rows. Size(0, h) keeps the pill free to stretch.
        minimumSize: const Size(0, AppSize.bigAction),
      ),
      child: Text(
        l10n.markWardDone,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A one-line status caption under the head.
class _Caption extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;

  const _Caption({
    required super.key,
    required this.icon,
    required this.text,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppTheme.colorTextMuted;
    return Row(
      spacing: AppSpace.xs,
      children: [
        Icon(icon, size: 16, color: tone),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(color: tone),
          ),
        ),
      ],
    );
  }
}

/// One 72 dp ward card (§4.17).
class _WardRow extends StatelessWidget {
  final WardStep step;

  final bool markEnabled;

  final Set<String> markInFlight;

  final void Function(String wardId) onMark;

  const _WardRow({
    required this.step,
    required this.markEnabled,
    required this.markInFlight,
    required this.onMark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;
    final inFlight = markInFlight.contains(step.ward.id);
    final canMark = !step.isDone && markEnabled && !inFlight;
    final next = step.isNext && !step.isDone;

    final row = Container(
      key: Key('liveRoute.wardRow.${step.ward.id}'),
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.lg,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: c.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        spacing: AppSpace.md,
        children: [
          _LeadingCircle(step: step),
          Expanded(
            child: Text(
              step.ward.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall.copyWith(
                color: AppTheme.colorTextPrimary,
                fontWeight: next ? FontWeight.bold : null,
              ),
            ),
          ),
          if (next)
            Container(
              key: const Key('liveRoute.nextChip'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.md,
                vertical: AppSpace.sm,
              ),
              decoration: BoxDecoration(
                color: c.primary,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                l10n.nextWardChip,
                style: context.text.label.copyWith(color: c.onPrimary),
              ),
            )
          else if (step.isDone) ...[
            Icon(
              Icons.check_circle,
              color: step.isFlagged ? c.statusEscalated.fill : c.primary,
              // Not const: the interpolated key depends on the ward id.
              key: Key('liveRoute.doneTick.${step.ward.id}'),
            ),
            Text(
              l10n.markDone,
              style: context.text.bodySmall.copyWith(color: c.textMuted),
            ),
            if (step.isFlagged)
              Icon(
                Icons.flag,
                size: 18,
                color: c.statusEscalated.fill,
                key: Key('liveRoute.flagged.${step.ward.id}'),
              ),
          ] else
            IconButton(
              // The out-of-order control (spec story 14 — real routes
              // rarely follow list order). Keyed per-ward; disabled while
              // no trip can receive the append or a write is in flight.
              key: Key('liveRoute.markWard.${step.ward.id}'),
              tooltip: l10n.markWardDoneSemantic(step.ward.name),
              onPressed: canMark ? () => onMark(step.ward.id) : null,
              icon: const Icon(Icons.check_circle_outline),
              color: c.primary,
            ),
        ],
      ),
    );

    // Merged rows read as ONE node ("Ward 2, Done" / "Ward 1, Next"); the
    // pending row stays split so the out-of-order mark control remains its
    // own TalkBack target (it carries the ward-name semantic via tooltip).
    if (!step.isDone && !next) return row;
    return MergeSemantics(child: row);
  }
}

/// The 48 dp leading circle carrying the row's state (§4.17): `primary` +
/// number for the NEXT ward, `brand` + check for a DONE ward, `surface` +
/// number for a pending one. (The spec's `surfaceMuted` circle assumes a
/// surface row — on this surfaceMuted card the inverse reads the same way.)
class _LeadingCircle extends StatelessWidget {
  final WardStep step;

  const _LeadingCircle({required this.step});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final Color fill;
    final Widget child;
    if (step.isDone) {
      fill = c.brand;
      child = Icon(Icons.check, size: 24, color: c.onBrand);
    } else if (step.isNext) {
      fill = c.primary;
      child = Text(
        '${step.orderIndex + 1}',
        style: TextStyle(fontWeight: FontWeight.bold, color: c.onPrimary),
      );
    } else {
      fill = c.surface;
      child = Text(
        '${step.orderIndex + 1}',
        style: TextStyle(fontWeight: FontWeight.bold, color: c.textMuted),
      );
    }

    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: fill),
      child: child,
    );
  }
}

/// The head card's affordance arrow: points UP while there is more sheet to
/// pull, flips DOWN once the sheet is fully extended, animated either way
/// (device pass 2026-10-28). Listens to the live sheet controller so the
/// flip tracks the actual snap, not a gesture guess.
class _SheetArrow extends StatelessWidget {
  final DraggableScrollableController? controller;
  final double fullFraction;

  const _SheetArrow({required this.controller, required this.fullFraction});

  @override
  Widget build(BuildContext context) {
    Widget arrow(bool full) => AnimatedRotation(
      turns: full ? 0.5 : 0,
      duration: AppMotion.fast,
      curve: AppMotion.standard,
      child: Icon(Icons.expand_less, size: 28, color: AppTheme.colorPrimary),
    );

    final controller = this.controller;
    if (controller == null) return arrow(false);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final full =
            controller.isAttached && controller.size >= fullFraction - 0.01;
        return arrow(full);
      },
    );
  }
}
