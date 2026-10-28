/// D2 Live Route — the M1 Map shell (docs/DESIGN.md §3.3 / §4 / §4.17):
/// a GlassBar (route name, tracking badge, settings entry, language
/// toggle) over a full-bleed map, the ordered ward list in a draggable
/// pull-up sheet, and the driver PillNav at the bottom.
///
/// Everything behavioral is canonical and untouched by this file:
/// - the sealed state machine + retry (domain/live_route_state.dart,
///   live_route_providers.dart), rendered through ui/state_views.dart;
/// - the map with its van/ward markers (ui/live_route_map.dart);
/// - the ward rows and every mark seam (ui/ward_list_panel.dart);
/// - the mock-location warning (F-D9) and offline banner keys;
/// - the Mark Ward Done flow (ticket 07) plumbed through onMark.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/l10n/locale_controller.dart';
import 'package:driverapp/core/theme/app_colors.dart';
import 'package:driverapp/core/theme/app_text.dart';
import 'package:driverapp/core/theme/app_tokens.dart';
import 'package:driverapp/core/widgets/app_icon_button.dart';
import 'package:driverapp/core/widgets/glass_bar.dart';
import 'package:driverapp/core/widgets/pill_nav.dart';
import 'package:driverapp/features/tracking/mock_location_banner.dart';
import 'package:driverapp/features/notices/domain/notices_flow.dart';
import 'package:driverapp/features/notices/ui/notices_screen.dart';
import 'package:driverapp/features/pending_reports/ui/pending_reports_screen.dart';
import 'package:driverapp/features/end_shift/ui/end_shift_screen.dart';
import 'package:driverapp/features/settings/ui/settings_screen.dart';

import 'domain/live_route_state.dart';
import 'live_route_providers.dart';
import 'mark_ward_done_flow.dart';
import 'ui/live_route_map.dart';
import 'ui/state_views.dart';
import 'ui/ward_list_panel.dart';

import 'package:driverapp/core/widgets/draggable_sheet.dart';
import 'package:driverapp/features/shift_start/data/shift_tracking_auto_start.dart';
import 'package:driverapp/features/shift_start/domain/shift_session.dart';

/// D1 pushes this after Start Shift with its van id (the session owns it;
/// every live-route provider is a family keyed by that id — see
/// `live_route_providers.dart` for why it is an argument, not an override).
class LiveRouteScreen extends ConsumerStatefulWidget {
  const LiveRouteScreen({super.key, required this.vanId});

  /// The van the driver picked in D1 — selects van doc, open trip, route
  /// and wards streams.
  final String vanId;

  @override
  ConsumerState<LiveRouteScreen> createState() => _LiveRouteScreenState();
}

class _LiveRouteScreenState extends ConsumerState<LiveRouteScreen> {
  /// The sheet's extent controller — shared by three consumers: the sheet
  /// itself (drag/snap), the top overlay slide-out and the head card's
  /// affordance arrow (device pass 2026-10-28).
  final DraggableScrollableController _sheet = DraggableScrollableController();

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  /// Snap fractions derived from THIS screen's metrics (never device
  /// pixels — tokens + MediaQuery only, so the geometry holds on every
  /// phone):
  /// - collapsed (bottom-most): the sheet's chrome above the pill nav is
  ///   EXACTLY the grab strip + the head card's top padding, so the card's
  ///   TOP edge lands on the pill's TOP edge — the 80 dp card is then
  ///   masked 1:1 by the 80 dp pill. The "West Loop · 3 of 3" card hides
  ///   BEHIND the bottom navigation; only the grab handle peeks (measured
  ///   off the driver's own held position, 2026-10-28: sheet top 637 dp,
  ///   card top 669 dp == pill top).
  /// - middle: + one head card — the green ripple card fully visible above
  ///   the pill, nothing else ("just the green ripple thing").
  /// - full: covers the screen (the glass bar slides up and out).
  ({double collapsed, double middle, double full}) _sheetSnaps(
    MediaQueryData mq,
  ) {
    final h = mq.size.height;
    // The PillNav's full footprint: safe bottom + its bottom padding + pill.
    final navZone = mq.padding.bottom + AppSpace.lg + AppSize.navHeightDriver;
    final chrome =
        DraggableSheet.grabStripHeight + WardListPanel.headTopPadding;
    final collapsed = (navZone + chrome) / h;
    final middle = collapsed + WardListPanel.headCardHeight / h;
    return (
      collapsed: collapsed.clamp(0.12, 0.30),
      middle: middle.clamp(collapsed + 0.06, 0.40),
      full: 0.96,
    );
  }

  /// Vertical offset under the GlassBar for the banners below it:
  /// safe top + glass height + breathing room.
  static double get _belowGlassBar => AppSize.glassBarHeight + AppSpace.lg * 2;

  @override
  Widget build(BuildContext context) {
    final vanId = widget.vanId;
    final state = ref.watch(liveRouteStateProvider(vanId));
    final data = state is LiveRouteData ? state : null;
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top;
    final snaps = _sheetSnaps(mq);

    // Built ONCE per screen build — the AnimatedBuilder below only moves
    // them (identical child instances skip rebuilds during drag frames).
    final glassBar = GlassBar(
      leadingIcon: Icons.route,
      title: data != null && data.routeName.isNotEmpty
          ? data.routeName
          : l10n.liveRouteTitle,
      // The tracking badge is the SUBTITLE line (§4.17 pill in the
      // glass bar): as an action it squeezed the title out entirely
      // (device a11y tree: title node collapsed to 72 px).
      subtitleBadge: TrackingBadge(label: l10n.trackingNotificationTitle),
      actions: [
        AppIconButton(
          key: const Key('liveRoute.settings'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
          ),
          icon: Icons.settings,
          size: 48,
          isGlass: true,
          semanticsLabel: l10n.settingsTitle,
          tooltip: l10n.settingsTitle,
        ),
      ],
      showLanguageToggle: true,
      currentLocale: (ref.watch(localeControllerProvider) ?? const Locale('en'))
          .languageCode,
      onLanguageToggle: () => ref
          .read(localeControllerProvider.notifier)
          .setLocale(
            Locale(
              (ref.read(localeControllerProvider) ?? const Locale('en'))
                          .languageCode ==
                      'en'
                  ? 'gu'
                  : 'en',
            ),
          ),
    );

    final banners = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (data != null && data.isOffline)
          Material(
            key: const Key('liveRoute.offlineBanner'),
            color: c.brandSoft,
            borderRadius: const BorderRadius.all(
              Radius.circular(AppSpace.unit * 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, size: 18, color: c.textPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.offline} · ${l10n.offlineShowingCached}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall.copyWith(
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        // F-D2 outcome banner: the tracking auto-start state follows
        // the driver INTO the live route screen (the placeholder
        // renders the same state). Started/all clear renders
        // nothing — the TrackingBadge in the GlassBar is the calm
        // signal.
        const _TrackingStateBanner(),
        MockLocationWarningBanner(vanId: vanId),
      ],
    );

    return Scaffold(
      body: Stack(
        children: [
          // The full-bleed content: map (data), or the loading/error/empty
          // state views.
          Positioned.fill(
            child: switch (state) {
              LiveRouteLoading() => const LiveRouteLoadingView(),
              LiveRouteError() => LiveRouteErrorView(
                onRetry: () => ref.read(liveRouteRetryProvider(vanId))(),
              ),
              LiveRouteEmpty(reason: final reason) => LiveRouteEmptyView(
                reason: reason,
              ),
              LiveRouteData() => LiveRouteBody(
                data: data!,
                vanId: vanId,
                sheet: _sheet,
                snaps: snaps,
              ),
            },
          ),

          // Top overlays (banners + glass bar) slide UP and out of the
          // screen as the sheet approaches its full snap — the driver sees
          // the sheet take over the whole screen (device pass 2026-10-28).
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _sheet,
              builder: (context, _) {
                final t = _sheet.isAttached ? _sheet.size : 0.0;
                final slide = ((t - (snaps.full - 0.16)) / 0.15).clamp(
                  0.0,
                  1.0,
                );
                final barLift =
                    slide * (safeTop + AppSize.glassBarHeight + AppSpace.sm);
                // Banners sit lower — lift them past their own stack too.
                final bannerLift =
                    slide *
                    (safeTop + AppSize.glassBarHeight + AppSpace.lg + 200);
                return Stack(
                  children: [
                    Positioned(
                      top: safeTop + _belowGlassBar - bannerLift,
                      left: 16,
                      right: 16,
                      child: banners,
                    ),
                    Positioned(
                      top: -barLift,
                      left: 0,
                      right: 0,
                      child: glassBar,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The data body: full-bleed map + pull-up ward sheet + PillNav.
class LiveRouteBody extends ConsumerWidget {
  final LiveRouteData data;

  /// Same van id the screen was opened with — the mark flow needs it for
  /// its imperative reads of the van-keyed providers.
  final String vanId;

  /// The screen's shared sheet controller (extent → slide-out + arrow).
  final DraggableScrollableController sheet;

  /// Per-screen snap fractions (see `_LiveRouteScreenState._sheetSnaps`).
  final ({double collapsed, double middle, double full}) snaps;

  const LiveRouteBody({
    super.key,
    required this.data,
    required this.vanId,
    required this.sheet,
    required this.snaps,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final van = data.vanMarker;
    // The mark flow's write-process state (in-flight / writeFailed) — the
    // done state itself stays stream-only (ticket 07: no local "done").
    final markFlow = ref.watch(markWardDoneFlowProvider);
    // The open trip VALUE (never `.future`, the autoDispose stream wedge):
    // the mark controls disable while today's trip doc is absent — nothing
    // exists to append `wardsDone` into.
    final markEnabled = ref.watch(openTripProvider(vanId)).value != null;
    // The PillNav mirrors the unread count (§4.5: badge = unread only).
    final unreadCount = ref.watch(unreadNoticesCountProvider);

    return Stack(
      children: [
        // Base layer: the full-screen map.
        Positioned.fill(child: LiveRouteMap(data: data)),

        // The pull-up drawer: nav-sized ContourCard head (optically one
        // with the PillNav when collapsed), the one BigActionButton (§4.17)
        // and the 72 dp ward rows — all plain content of the sheet's single
        // scroll view (§4.11).
        DraggableSheet(
          controller: sheet,
          // Open DOWN: collapsed so the nav-sized head card is hidden behind
          // the PillNav — the two read as ONE optically-merged unit at rest.
          initialSize: snaps.collapsed,
          snapPoints: [snaps.collapsed, snaps.middle, snaps.full],
          builder: (_) => WardListPanel(
            routeName: data.routeName,
            wardSteps: data.wardSteps,
            staleMinutes: van != null && van.isStale
                ? van.minutesSinceUpdate
                : null,
            isOffline: data.isOffline,
            markInFlight: markFlow.inFlight,
            markWriteFailed: markFlow.writeFailed,
            markEnabled: markEnabled,
            // The mark event plumbs straight into the flow (dedupe, guard,
            // flagged decision and the single appendWardDone live there).
            onMark: (wardId) =>
                ref.read(markWardDoneFlowProvider.notifier).mark(vanId, wardId),
            // Route complete → the sheet's primary turns into the ticket-08
            // End Shift entry. The old end-trip banner on the map is gone
            // (device UX pass 2026-10-28).
            onEndShift: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EndShiftScreen(vanId: vanId),
              ),
            ),
            sheetController: sheet,
            sheetFullFraction: snaps.full,
          ),
        ),

        // Driver PillNav (Route / Notices / Reports). Notices pushes the
        // inbox; Route is this screen; Reports awaits its ticket.
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: PillNav.driver(
            currentIndex: 0,
            labels: [l10n.navRoute, l10n.navNotices, l10n.navReports],
            badges: {
              DriverNavItem.notices: unreadCount,
              DriverNavItem.reports: 0,
            },
            onTap: (index) {
              if (index == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NoticesScreen(),
                  ),
                );
              } else if (index == 2) {
                // D4 Pending Reports (F-D6): today's missed-collection
                // complaints for this route's wards.
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PendingReportsScreen(),
                  ),
                );
              }
              // Route (0) is already this screen.
            },
          ),
        ),
      ],
    );
  }
}

/// F-D2 tracking state banner for the active-shift screen: the
/// permission/outcome state from [ShiftTrackingAutoStartStatusProvider]
/// must stay visible wherever a shift is live (silence is never a
/// state — same mirrored defect as the placeholder). gpsOff keeps the
/// open-settings recovery; denied keeps Retry; started renders nothing.
class _TrackingStateBanner extends ConsumerWidget {
  const _TrackingStateBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = ref.watch(shiftTrackingAutoStartStatusProvider);
    if (outcome == null || outcome.kind == ShiftTrackingAutoStartKind.started) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(shiftControllerProvider);
    final starter = ref.read(shiftTrackingAutoStarterProvider);
    final c = context.colors;

    return Material(
      key: const Key('liveRoute.trackingStateBanner'),
      color: c.brandSoft,
      borderRadius: const BorderRadius.all(Radius.circular(AppSpace.unit * 2)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.location_off, size: 18, color: c.textPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                outcome.kind == ShiftTrackingAutoStartKind.gpsOff
                    ? l10n.trackingGpsOff
                    : l10n.trackingPermissionDenied,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(width: AppSpace.sm),
            if (outcome.kind == ShiftTrackingAutoStartKind.gpsOff)
              FilledButton(
                key: const ValueKey('tracking-open-gps-settings'),
                onPressed: () => unawaited(starter.openLocationSettings()),
                child: Text(l10n.trackingOpenLocationSettings),
              ),
            TextButton(
              key: const ValueKey('tracking-start-retry'),
              onPressed: session == null
                  ? null
                  : () => unawaited(
                      starter.startTrackingFor(
                        session,
                        notificationTitle: l10n.trackingNotificationTitle,
                        notificationBody: l10n.trackingNotificationBody,
                      ),
                    ),
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}
