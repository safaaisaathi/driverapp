/// Riverpod wiring for the D2 Live Route screen (PRD-2 F-D3 build step 1,
/// architecture 0.11: data only through repositories).
///
/// Everything here is `autoDispose`: Riverpod keeps the repository listeners
/// open only while the screen watches them and cancels them on dispose
/// (0.11) — no manual lifecycle wiring needed.
///
/// Every provider below is a FAMILY keyed by the van id. The van id is a
/// plain argument handed over by D1 Shift Start (its session owns it), not a
/// provider override: Riverpod 3 resolves a provider that a nested scope
/// does not override in the PARENT container, so the previous
/// `currentVanIdProvider.overrideWithValue(...)` seam silently resolved
/// without the override on device (defect 2026-10-28: "must be overridden"
/// thrown inside the van-doc leg). An explicit argument cannot miss.
///
/// Feature tests never touch this file's repository wiring: they run under
/// `ProviderScope(overrides: [...])` with the seam fakes
/// (test/repositories/fake_repositories.dart) in place of every repository
/// provider, plus overrides for [offlineStatusProvider] and
/// [tileUrlTemplateProvider] where needed.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import 'package:driverapp/features/tracking/offline/offline_providers.dart';

import 'domain/live_route_state.dart';

/// The van doc stream (its own `vans/{vanId}` document — the marker source,
/// PRD-2 F-D2: `watchVan` → `lastLocation`), keyed by the van id D1 hands
/// over.
final vanDocProvider =
    StreamProvider.autoDispose.family<Van?, String>(
  (ref, vanId) => ref
      .watch(vansRepositoryProvider)
      .watchVan(vanId)
      .handleError((error, stackTrace) {
        debugPrint('live-route: vanDoc stream error: $error');
        debugPrint(stackTrace.toString().split('\n').take(14).join(' ~ '));
        throw error;
      }),
);

/// Today's open trip for the van (source of the done-tick set,
/// `trips.wardsDone`). The repository bounds the query to `today` in IST
/// (0.13 "Today"); a null emission means no trip (yet) today.
final openTripProvider =
    StreamProvider.autoDispose.family<Trip?, String>(
  (ref, vanId) => ref.watch(tripsRepositoryProvider).watchTripByVanIdAndDate(
        vanId: vanId,
        date: DateTime.now(),
      ),
);

/// The route doc (the visiting order lives ONLY in `routes.wardIds`, 0.2).
/// One shot read — route order is a seeded contract list, not live data.
///
/// Watches the van VALUE (never `vanDocProvider.future`): awaiting the
/// `.future` of an autoDispose stream provider wedges Riverpod 3.4
/// ("disposed during loading") whenever the chain invalidates mid-load —
/// retry taps and van-doc updates both hit that.
final routeModelProvider =
    FutureProvider.autoDispose.family<RouteModel?, String>((ref, vanId) async {
  final van = ref.watch(vanDocProvider(vanId)).value;
  if (van == null) return null;
  return ref.watch(routesRepositoryProvider).readRoute(van.routeId);
});

/// The route's ward docs, kept current through `watchRouteWards` while the
/// screen is visible (ward positions/names are admin-edited seed data). The
/// provider re-subscribes when the van (and with it the route) changes.
final routeWardsProvider =
    StreamProvider.autoDispose.family<List<Ward>, String>((ref, vanId) async* {
  // Watch the route VALUE, never `routeModelProvider.future` — same
  // Riverpod 3.4 "disposed during loading" wedge as the van doc above.
  final route = ref.watch(routeModelProvider(vanId)).value;
  if (route == null) {
    // No route doc (yet): emit one empty frame so the state does not hang
    // on loading (the reducer turns the missing route into the empty
    // state, and a later route still re-runs this body).
    yield const <Ward>[];
    return;
  }
  await for (final wards in ref
      .watch(wardsRepositoryProvider)
      .watchRouteWards(route.id)) {
    yield wards;
  }
});

/// Offline seam (0.13: dead zones are normal; the screen keeps rendering
/// cached data with an offline badge instead of failing).
///
/// The F-D7 offline ticket (ticket 12) shipped the real detector
/// (connectivity_plus, [connectivitySourceProvider]) but never flipped this
/// default, so the badge was permanently hidden. Interface presence is
/// enough here: a dead zone shows the badge while Firestore persistence
/// keeps the cached data rendering. The source emits `true` = reachable, so
/// the offline value is its inverse. Feature tests override this provider
/// (the pump harnesses do it for every test) to drive the state
/// hermetically.
final StreamProvider<bool> offlineStatusProvider =
    StreamProvider.autoDispose<bool>((ref) {
  return ref.watch(connectivitySourceProvider).status.map((online) => !online);
});

/// Whether the device is currently offline, from [offlineStatusProvider] —
/// an errored/not-yet-emitted stream means online.
final Provider<bool> isOfflineProvider = Provider.autoDispose<bool>((ref) {
  final status = ref.watch(offlineStatusProvider);
  // An errored/pending offline stream means "no reading yet" → online.
  return status.hasValue ? status.value! : false;
});

/// OSM tile URL for the map's base layer (PRD section 6 pins flutter_map +
/// OpenStreetMap). Exposure as a provider let tests run the screen without
/// network tile fetches (override with `null` → base layer omitted).
final Provider<String?> tileUrlTemplateProvider = Provider<String?>((ref) {
  return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
});

/// [LiveRouteState] derived from the repository-backed providers above —
/// the one provider the screen watches. Pure mapping logic (error → empty →
/// loading precedence, ward order, done set, stale marker) lives in
/// `domain/live_route_state.dart` and is unit tested directly; this provider
/// only wires the streams to it.
final liveRouteStateProvider =
    Provider.autoDispose.family<LiveRouteState, String>((ref, vanId) {
  return combineLiveRouteState(
    van: ref.watch(vanDocProvider(vanId)),
    trip: ref.watch(openTripProvider(vanId)),
    route: ref.watch(routeModelProvider(vanId)),
    wards: ref.watch(routeWardsProvider(vanId)),
    isOffline: ref.watch(isOfflineProvider),
    now: DateTime.now(),
  );
});

/// Retry action for the error state: re-reads every watched provider. The
/// autoDispose chains re-subscribe on the next watch (0.11: cancelled on
/// dispose applies equally to a manual retry).
final liveRouteRetryProvider =
    Provider.autoDispose.family<void Function(), String>((ref, vanId) {
  return () {
    ref.invalidate(vanDocProvider(vanId));
    ref.invalidate(openTripProvider(vanId));
    ref.invalidate(routeModelProvider(vanId));
    ref.invalidate(routeWardsProvider(vanId));
  };
});
