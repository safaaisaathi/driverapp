/// D2 Live Route — the driver's home screen after shift start (PRD-2
/// section 3, F-D3 step 1): full-screen map, the van marker from the van's
/// own doc stream, ward markers in `routes.wardIds` order with done wards
/// ticked from `trips.wardsDone` of the open trip, and the ordered ward list
/// overlaid beneath with the first undone ward highlighted "next".
///
/// The app bar carries the Notices slot (unread-badge placeholder, ticket 09
/// wires the inbox) and a small End-of-trip card placeholder (ticket 08
/// wires the summary card). Mark Ward Done (ticket 07) will anchor to the
/// next-ward row.
///
/// All listeners live in `live_route_providers.dart` under `autoDispose` —
/// they are open only while this screen is in the tree and are cancelled on
/// dispose (0.11).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/theme/app_theme.dart';

import 'package:driverapp/features/tracking/mock_location_banner.dart';

import 'domain/live_route_state.dart';

import 'live_route_providers.dart';
import 'mark_ward_done_flow.dart';
import 'ui/live_route_map.dart';
import 'ui/state_views.dart';
import 'ui/ward_list_panel.dart';

/// The D2 screen. D1 pushes it after Start Shift with its van id overriding
/// [currentVanIdProvider].
class LiveRouteScreen extends ConsumerWidget {
  const LiveRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(liveRouteStateProvider);
    final data = state is LiveRouteData ? state : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          data != null && data.routeName.isNotEmpty
              ? data.routeName
              : AppLocalizations.of(context)!.liveRouteTitle,
        ),
        actions: [
          IconButton(
            // Notices slot — badge placeholder; ticket 09 wires the inbox and
            // the unread count. Keyed for the integration.
            key: const Key('liveRoute.noticesPlaceholder'),
            onPressed: null,
            icon: const Badge(
              isLabelVisible: false,
              child: Icon(Icons.notifications),
            ),
            tooltip: AppLocalizations.of(context)!.noticesBadgeTooltip,
          ),
        ],
      ),
      body: Column(
        children: [
          // F-D9: mock-location warning — self-contained, renders nothing
          // unless the van's trip doc latched a mock fix (ticket 11).
          MockLocationWarningBanner(vanId: ref.watch(currentVanIdProvider)),
          Expanded(
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
        ],
      ),
    );
  }
}

/// The data body: map + placeholders + ward list overlaid.
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
        // Top overlay: offline badge over the map (cached rendering keeps
        // working) + the End-of-trip card placeholder (ticket 08 replaces
        // the child).
        Positioned(
          top: 8,
          left: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: data.isOffline
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            spacing: 8,
            children: [
              if (data.isOffline)
                Material(
                  key: const Key('liveRoute.offlineBanner'),
                  color: AppTheme.colorStatusReceived,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(AppTheme.radiusMd),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${l10n.offline} · ${l10n.offlineShowingCached}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ExcludeSemantics(
                child: Container(
                  key: const Key('liveRoute.endTripPlaceholder'),
                  constraints:
                      const BoxConstraints(minWidth: 48, minHeight: 48),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.colorSurface,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppTheme.radiusMd),
                    ),
                    border: Border.all(color: AppTheme.colorTextMuted),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flag_outlined, size: 20),
                      const SizedBox(width: 8),
                      // Expanded: a Row hands children unbounded width — the
                      // long label overflowed and killed the whole subtree
                      // in tests (RenderFlex overflow 67px).
                      Expanded(
                        child: Text(
                          l10n.endOfTripCardPlaceholder,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: AppTheme.colorTextMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Ordered ward list over the bottom, thumb zone.
        Align(
          alignment: Alignment.bottomCenter,
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
      ],
    );
  }
}
