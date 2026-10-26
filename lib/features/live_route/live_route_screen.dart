/// D2 Live Route — the M1 Map shell (docs/DESIGN.md §3.3 / §4 / §4.17):
/// a GlassBar (route name, tracking badge, notices slot, language toggle)
/// over a full-bleed map, the ordered ward list in a draggable pull-up
/// sheet, and the driver PillNav at the bottom.
///
/// Everything behavioral is canonical and untouched by this file:
/// - the sealed state machine + retry (domain/live_route_state.dart,
///   live_route_providers.dart), rendered through ui/state_views.dart;
/// - the map with its van/ward markers (ui/live_route_map.dart);
/// - the ward rows and every mark seam (ui/ward_list_panel.dart);
/// - the mock-location warning (F-D9) and offline banner keys;
/// - the Mark Ward Done flow (ticket 07) plumbed through onMark.
library;

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

import 'domain/live_route_state.dart';
import 'live_route_providers.dart';
import 'mark_ward_done_flow.dart';
import 'ui/live_route_map.dart';
import 'ui/state_views.dart';
import 'ui/ward_list_panel.dart';
import '../../core/widgets/draggable_sheet.dart';

/// D1 pushes this after Start Shift with its van id overriding
/// [currentVanIdProvider].
class LiveRouteScreen extends ConsumerWidget {
  const LiveRouteScreen({super.key});

  /// Vertical offset under the GlassBar for the banners below it:
  /// safe top + glass height + breathing room.
  static double get _belowGlassBar => AppSize.glassBarHeight + AppSpace.lg * 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveRouteStateProvider);
    final data = state is LiveRouteData ? state : null;
    final unreadCount = ref.watch(unreadNoticesCountProvider);
    // Route complete = every ward step ticked in the stream state. Only then
    // does the end-of-trip slot turn into the ticket-08 End Shift entry.
    final routeComplete =
        data != null && data.wardSteps.isNotEmpty && data.wardSteps.every(
            (step) => step.isDone);
    final l10n = AppLocalizations.of(context)!;
    final c = context.colors;

    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // The full-bleed content: map (data), or the loading/error/empty
          // state views. The GlassBar stays up in every state — the driver
          // never loses the notices slot.
          Positioned.fill(
            child: switch (state) {
              LiveRouteLoading() => const LiveRouteLoadingView(),
              LiveRouteError() => LiveRouteErrorView(
                  onRetry: () => ref.read(liveRouteRetryProvider)(),
                ),
              LiveRouteEmpty(reason: final reason) =>
                LiveRouteEmptyView(reason: reason),
              LiveRouteData() => LiveRouteBody(data: data!),
            },
          ),

          // Banners directly under the glass bar (offline note over the map,
          // mock-location warning F-D9, end-of-trip card seam). All render
          // nothing when their condition is false, so one slot serves all.
          Positioned(
            top: safeTop + _belowGlassBar,
            left: 16,
            right: 16,
            child: Column(
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_off,
                              size: 18, color: c.textPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${l10n.offline} · ${l10n.offlineShowingCached}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall
                                  .copyWith(color: c.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                MockLocationWarningBanner(
                  vanId: ref.watch(currentVanIdProvider),
                ),
                if (data != null)
                  ExcludeSemantics(
                    child: Container(
                      key: const Key('liveRoute.endTripPlaceholder'),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: routeComplete ? c.brandSoft : c.surface,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(AppSpace.unit * 2),
                        ),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            routeComplete
                                ? Icons.check_circle
                                : Icons.flag_outlined,
                            size: 20,
                            color: routeComplete
                                ? c.textPrimary
                                : c.textMuted,
                          ),
                          const SizedBox(width: 8),
                          // Expanded: a Row hands children unbounded width —
                          // the long label overflowed and killed the whole
                          // subtree in tests (RenderFlex overflow 67px).
                          Expanded(
                            child: Text(
                              routeComplete
                                  ? l10n.endShiftHint
                                  : l10n.endOfTripCardPlaceholder,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall.copyWith(
                                color: routeComplete
                                    ? c.textPrimary
                                    : c.textMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpace.sm),
                          if (routeComplete)
                            // Ticket 08 entry (route complete only): one
                            // tap to the D5 summary — no mark control
                            // remains, so this is the screen's ONE primary.
                            FilledButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const EndShiftScreen()),
                              ),
                              child: Text(l10n.endShiftPrimary),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // M1 top element: the GlassBar (route name + tracking + notices +
          // language toggle). Painted last among the top overlays.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: GlassBar(
              title: data != null && data.routeName.isNotEmpty
                  ? data.routeName
                  : l10n.liveRouteTitle,
              actions: [
                TrackingBadge(label: l10n.trackingNotificationTitle),
                SizedBox(width: AppSpace.sm),
                _NoticesSlot(
                  unreadCount: unreadCount,
                  semantic: l10n.noticesBadgeTooltip,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const NoticesScreen()),
                  ),
                ),
              ],
              showLanguageToggle: true,
              currentLocale: (ref.watch(localeControllerProvider) ??
                      const Locale('en'))
                  .languageCode,
              onLanguageToggle: () => ref
                  .read(localeControllerProvider.notifier)
                  .setLocale(
                    Locale(
                      (ref.read(localeControllerProvider) ??
                                  const Locale('en'))
                              .languageCode ==
                          'en'
                          ? 'gu'
                          : 'en',
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The notices slot in the GlassBar: keyed for tests, unread dot badge from
/// the D3 inbox flow; tap routes to the inbox.
class _NoticesSlot extends StatelessWidget {
  final int unreadCount;
  final String semantic;
  final VoidCallback onTap;

  const _NoticesSlot({
    required this.unreadCount,
    required this.semantic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        AppIconButton(
          key: const Key('liveRoute.noticesPlaceholder'),
          onPressed: onTap,
          icon: Icons.notifications,
          size: 48,
          isGlass: true,
          semanticsLabel: semantic,
          tooltip: semantic,
        ),
        if (unreadCount > 0)
          Positioned(
            top: 6,
            right: 6,
            child: Container(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: context.colors.accentStrong,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: context.text.attribution.copyWith(
                    color: context.colors.onAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The data body: full-bleed map + pull-up ward sheet + PillNav.
class LiveRouteBody extends ConsumerWidget {
  final LiveRouteData data;

  const LiveRouteBody({super.key, required this.data});

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
    final markEnabled = ref.watch(openTripProvider).value != null;

    return Stack(
      children: [
        // Base layer: the full-screen map.
        Positioned.fill(child: LiveRouteMap(data: data)),

        // The pull-up drawer: ordered ward rows under a ContourCard route
        // progress head (CL-12). Drags between the collapsed / default /
        // expanded snaps of the shell component.
        DraggableSheet(
          initialSize: 0.36,
          navHeight: AppSize.navHeightDriver,
          child: WardListPanel(
            routeName: data.routeName,
            wardSteps: data.wardSteps,
            staleMinutes:
                van != null && van.isStale ? van.minutesSinceUpdate : null,
            isOffline: data.isOffline,
            markInFlight: markFlow.inFlight,
            markWriteFailed: markFlow.writeFailed,
            markEnabled: markEnabled,
            // The mark event plumbs straight into the flow (dedupe, guard,
            // flagged decision and the single appendWardDone live there).
            onMark: (wardId) =>
                ref.read(markWardDoneFlowProvider.notifier).mark(wardId),
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
            labels: [
              l10n.navRoute,
              l10n.navNotices,
              l10n.navReports,
            ],
            badges: {DriverNavItem.notices: 0, DriverNavItem.reports: 0},
            onTap: (index) {
              if (index == 1) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const NoticesScreen()),
                );
              } else if (index == 2) {
                // D4 Pending Reports (F-D6): today's missed-collection
                // complaints for this route's wards.
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const PendingReportsScreen()),
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
