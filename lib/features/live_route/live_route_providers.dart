/// Riverpod wiring for the D2 Live Route screen (PRD-2 F-D3 build step 1,
/// architecture 0.11: data only through repositories).
///
/// Everything here is `autoDispose`: Riverpod keeps the repository listeners
/// open only while the screen watches them and cancels them on dispose
/// (0.11) — no manual lifecycle wiring needed.
///
/// Feature tests never touch this file: they run under
/// `ProviderScope(overrides: [...])` with the seam fakes
/// (test/repositories/fake_repositories.dart) in place of every repository
/// provider, plus overrides for [currentVanIdProvider], [offlineStatusProvider]
/// and [tileUrlTemplateProvider] where needed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';

import 'domain/live_route_state.dart';

/// The van the signed-in driver chose in D1 and started a shift for.
///
/// Default throws: the value comes from D1 Shift Start (its
/// sign-in/start-shift result), which does not exist yet — an accidental
/// production read must fail loudly, not show the wrong van. D1 integration
/// (or a feature test / the dev demo) overrides it:
///
/// ```dart
/// currentVanIdProvider.overrideWithValue('van-01')
/// ```
final Provider<String> currentVanIdProvider = Provider<String>((ref) {
  throw UnimplementedError(
    'currentVanIdProvider must be overridden by D1 Shift Start '
    '(dev demo: dev_live_route.dart); a throw keeps a wrong van off the map.',
  );
});

/// The van doc stream (its own `vans/{vanId}` document — the marker source,
/// PRD-2 F-D2: `watchVan` → `lastLocation`).
final StreamProvider<Van?> vanDocProvider = StreamProvider.autoDispose<Van?>(
  (ref) => ref
      .watch(vansRepositoryProvider)
      .watchVan(ref.watch(currentVanIdProvider)),
);

/// Today's open trip for this van (source of the done-tick set,
/// `trips.wardsDone`). The repository bounds the query to `today` in IST
/// (0.13 "Today"); a null emission means no trip (yet) today.
final StreamProvider<Trip?> openTripProvider = StreamProvider.autoDispose<Trip?>(
  (ref) => ref.watch(tripsRepositoryProvider).watchTripByVanIdAndDate(
        vanId: ref.watch(currentVanIdProvider),
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
final FutureProvider<RouteModel?> routeModelProvider =
    FutureProvider.autoDispose<RouteModel?>((ref) async {
  final van = ref.watch(vanDocProvider).value;
  if (van == null) return null;
  return ref.watch(routesRepositoryProvider).readRoute(van.routeId);
});

/// The route's ward docs, kept current through `watchRouteWards` while the
/// screen is visible (ward positions/names are admin-edited seed data). The
/// provider re-subscribes when the van (and with it the route) changes.
final StreamProvider<List<Ward>> routeWardsProvider =
    StreamProvider.autoDispose<List<Ward>>((ref) async* {
  // Watch the route VALUE, never `routeModelProvider.future` — same
  // Riverpod 3.4 "disposed during loading" wedge as the van doc above.
  final route = ref.watch(routeModelProvider).value;
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
/// The default is "online": Firestore persistence (F-D7) already keeps data
/// fresh from cache, and detectable connectivity needs a platform channel
/// (e.g. connectivity_plus — NOT allowed here, pubspec changes are only for
/// the map package). The F-D7 offline-sync ticket owns the real detector and
/// swaps this provider's default over; feature tests override it to drive
/// the offline state hermetically.
final StreamProvider<bool> offlineStatusProvider =
    StreamProvider.autoDispose<bool>((ref) {
  // TODO(F-D7 offline ticket): replace with a real connectivity source.
  return const Stream<bool>.empty();
});

/// Whether the device is currently offline, from [offlineStatusProvider] —
/// an empty stream (no detector) means online.
final Provider<bool> isOfflineProvider = Provider.autoDispose<bool>((ref) {
  final status = ref.watch(offlineStatusProvider);
  // An errored/empty offline stream means "no detector wired" → online.
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
final Provider<LiveRouteState> liveRouteStateProvider =
    Provider.autoDispose<LiveRouteState>((ref) {
  return combineLiveRouteState(
    van: ref.watch(vanDocProvider),
    trip: ref.watch(openTripProvider),
    route: ref.watch(routeModelProvider),
    wards: ref.watch(routeWardsProvider),
    isOffline: ref.watch(isOfflineProvider),
    now: DateTime.now(),
  );
});

/// Retry action for the error state: re-reads every watched provider. The
/// autoDispose chains re-subscribe on the next watch (0.11: cancelled on
/// dispose applies equally to a manual retry).
final Provider<void Function()> liveRouteRetryProvider =
    Provider.autoDispose<void Function()>((ref) {
  return () {
    ref.invalidate(vanDocProvider);
    ref.invalidate(openTripProvider);
    ref.invalidate(routeModelProvider);
    ref.invalidate(routeWardsProvider);
  };
});
