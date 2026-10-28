import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// DraggableSheet — bottom sheet on M1 (Map shell).
/// DESIGN.md Section 3.3 / 4.11.
///
/// ONE scrollable owns the sheet: a [DraggableScrollableSheet] whose linked
/// scroll view drives both the list and the sheet height. Dragging the
/// content — or the grab handle at its top — scrolls the list and, once the
/// list reaches its edge, moves the sheet between the snap points. Scrolling
/// is never nested (§4.11): the panel builds plain children inside this
/// scroll view, and the old hand-rolled GestureDetector + inner
/// SingleChildScrollView pairing (two scrollables fighting over the same
/// drags) is gone with it.
///
/// Radius 32 top, surface, elev3, grab handle 40x4 borderStrong. The
/// content's bottom padding includes the full nav zone so rows are never
/// covered by the pill nav, and the scroll content is CLIPPED at the nav
/// pill's bottom edge — nothing may paint in the strip under the floating
/// pill (the driver saw a cream sliver of the End Shift button there,
/// 2026-10-28 device pass).
///
/// Snap points (defaults; the live route computes exact per-screen fractions
/// so the collapsed peek hides the nav-sized head card BEHIND the pill nav):
/// collapsed ≈ 0.18 (grab handle only peeks; card top == pill top, so the
/// 80 dp card is masked 1:1 by the 80 dp pill), middle ≈ 0.29 (the head card
/// fully visible above the pill — "just the green ripple thing"), full 0.96
/// (covers the screen — the glass bar slides up and out).
class DraggableSheet extends StatelessWidget {
  const DraggableSheet({
    super.key,
    required this.builder,
    this.controller,
    this.initialSize = defaultFraction,
    this.snapPoints = defaultSnapPoints,
    this.navHeight = AppSize.navHeightDriver,
  });

  static const double collapsedFraction = 0.18;
  static const double defaultFraction = 0.29;
  static const double expandedFraction = 0.96;
  static const List<double> defaultSnapPoints = [
    collapsedFraction,
    defaultFraction,
    expandedFraction,
  ];

  /// The grab-handle strip's height: its top margin (md) + the 4 dp bar +
  /// its bottom margin (sm). The live route adds this to the nav zone when
  /// computing the collapsed fraction — the strip is the ONLY chrome that
  /// may peek above the pill nav at the bottom-most snap.
  static const double grabStripHeight = AppSpace.md + 4 + AppSpace.sm;

  /// Builds the sheet's CONTENT. No scrolling of its own — the sheet owns
  /// the single viewport (§4.11).
  final WidgetBuilder builder;

  /// Optional external controller — the live route screen listens to it to
  /// slide the top overlays away as the sheet reaches full extent, and the
  /// head card flips its affordance arrow.
  final DraggableScrollableController? controller;

  final double initialSize;
  final List<double> snapPoints;

  /// Bottom reserve so content clears the pill nav overlay.
  final double navHeight;

  @override
  Widget build(BuildContext context) {
    final snaps = [...snapPoints]..sort();
    final snapSizes = snaps.length > 2
        ? snaps.sublist(1, snaps.length - 1)
        : const <double>[];

    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      bottom: 0,
      child: DraggableScrollableSheet(
        controller: controller,
        initialChildSize: initialSize.clamp(snaps.first, snaps.last),
        minChildSize: snaps.first,
        maxChildSize: snaps.last,
        snap: true,
        snapSizes: snapSizes,
        builder: (context, scrollController) {
          final c = context.colors;
          // The PillNav's footprint BELOW its pill: the safe inset it sits
          // on + its own bottom padding (AppSpace.lg). The sheet's bottom is
          // the screen's bottom, so this band is exactly the strip where the
          // floating pill does NOT cover the sheet — content is clipped
          // above it (see clipper below).
          final underPillBand =
              MediaQuery.paddingOf(context).bottom + AppSpace.lg;
          // Full nav zone: the reserve content needs so its END can scroll
          // clear of the pill (pill bottom + pill height).
          final navZone = underPillBand + navHeight;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.sheet),
              ),
              boxShadow: Theme.of(context).brightness == Brightness.dark
                  ? AppElevation.elev3Dark
                  : AppElevation.elev3,
            ),
            child: ClipRect(
              // Content — never the surface — must stop at the pill's bottom
              // edge: the strip under the floating pill shows only surface
              // (a cream button sliver leaked there once, 2026-10-28).
              clipper: _UnderPillClipper(band: underPillBand),
              child: CustomScrollView(
                controller: scrollController,
                // Short content (few wards) must still answer a drag with
                // sheet movement, never dead glass.
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Grab handle inside the scroll view: dragging IT is dragging
                  // the linked scroll position, so the sheet follows.
                  SliverToBoxAdapter(
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(
                          top: AppSpace.md,
                          bottom: AppSpace.sm,
                        ),
                        decoration: BoxDecoration(
                          color: c.borderStrong,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      // Horizontal inset matches the PillNav's (AppSpace.lg) —
                      // the collapsed head card must sit flush above the nav,
                      // optically ONE unit (device pass 2026-10-28).
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.lg,
                        0,
                        AppSpace.lg,
                        navZone,
                      ),
                      child: builder(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Cuts the scroll content's paint region above the strip under the floating
/// pill nav (`band` measured from the bottom). The sheet's SURFACE keeps
/// filling that strip; only content is masked — the pill's rounded shoulders
/// would otherwise expose slivers of whatever content scrolled past.
class _UnderPillClipper extends CustomClipper<Rect> {
  const _UnderPillClipper({required this.band});

  /// Height of the exposed strip under the pill, in sheet-local dp.
  final double band;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width, size.height - band);

  @override
  bool shouldReclip(_UnderPillClipper oldClipper) => oldClipper.band != band;
}
