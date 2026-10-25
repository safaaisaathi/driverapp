/// Widget + provider streaming tests for the D2 Live Route screen (ticket 06,
/// spec seam 1): the full screen under a `ProviderScope` whose repository
/// providers are the seam fakes — NO platform channels. flutter_map's network
/// TileLayer is swapped out by overriding `tileUrlTemplateProvider` with
/// `null`, keeping tests hermetic; the real map ships the OSM layer.
library;

import 'dart:async';

import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/features/live_route/live_route_providers.dart';
import 'package:driverapp/features/live_route/live_route_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../repositories/fake_repositories.dart';

/// Wraps [inner] with an active-listener count (proves Riverpod cancels the
/// repository listener on screen dispose, 0.11).
class CountingVansRepository implements VansRepository {
  CountingVansRepository(this.inner);

  final VansRepository inner;

  int activeListeners = 0;

  @override
  Stream<Van?> watchVan(String vanId) {
    final counted = StreamController<Van?>();
    activeListeners++;
    late StreamSubscription<Van?> sub;
    counted.onListen = () {
      // scheduleMicrotask: the inner fake adds synchronously during ITS
      // onListen — piping straight into `counted` re-enters this controller
      // while it is itself adding ("Cannot add event while adding stream").
      scheduleMicrotask(() {
        sub = inner.watchVan(vanId).listen(counted.add,
            onError: counted.addError, onDone: counted.close);
      });
    };
    counted.onCancel = () {
      activeListeners--;
      sub.cancel();
    };
    return counted.stream;
  }

  @override
  Future<List<Van>> readVans() => inner.readVans();

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) =>
      inner.updateLastLocation(
        vanId: vanId,
        lat: lat,
        lng: lng,
        speedKmph: speedKmph,
        updatedAt: updatedAt,
      );

  @override
  Future<void> updateStatus(String vanId, VanStatus status) =>
      inner.updateStatus(vanId, status);

  @override
  Future<void> updateBatteryPct(String vanId, int batteryPct) =>
      inner.updateBatteryPct(vanId, batteryPct);
}

/// A vans repository that only errors — drives the error state. Emits null
/// first: Riverpod 3.4's `.future` never completes on an error-first stream,
/// and a container disposed mid-loading throws ("disposed during loading").
class ThrowingVansRepository implements VansRepository {
  @override
  Stream<Van?> watchVan(String vanId) async* {
    yield null;
    throw Exception('down');
  }

  @override
  Future<List<Van>> readVans() async => [];

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) async {}

  @override
  Future<void> updateStatus(String vanId, VanStatus status) async {}

  @override
  Future<void> updateBatteryPct(String vanId, int batteryPct) async {}
}

void main() {
  // Real clock: the open-trip provider filters by TODAY's calendar day, so
  // seeded trips must carry today's date to be found (fixed past dates made
  // the done-tick tests miss their own trip).
  final now = DateTime.now();

  Ward ward(String id, double lat) => Ward.fromMap({
        'id': id,
        'name': 'Ward $id',
        'nameGu': 'gu',
        'code': 'c-$id',
        'type': 'urban',
        'center': {'lat': lat, 'lng': 73.71},
        'radiusM': 400,
        'routeId': 'route-01',
        'inspectorId': 'staff-01',
        'escalationTo': 'staff-09',
      });

  RouteModel route({List<String> wardIds = const ['wa', 'wb', 'wc']}) =>
      RouteModel.fromMap({
        'id': 'route-01',
        'name': 'Godhra Fort Route',
        'wardIds': wardIds,
        'scheduledStartTime': '07:30',
      });

  Van van({DateTime? updatedAt}) => Van.fromMap({
        'id': 'van-01',
        'plateNo': 'GJ-05-AB-1234',
        'routeId': 'route-01',
        'status': 'on_shift',
        'lastLocation': updatedAt == null
            ? null
            : {
                'lat': 22.7759,
                'lng': 73.7092,
                'updatedAt': updatedAt,
                'speedKmph': 12.5,
              },
        'currentTripId': null,
        'batteryPct': 76,
      });

  Trip tripFrom(List<Map<String, Object?>> wardsDone) => Trip.fromMap({
        'id': 'trip-1',
        'vanId': 'van-01',
        'routeId': 'route-01',
        'date': now,
        'startedAt': now,
        'endedAt': null,
        'wardsDone': wardsDone,
        'alertedWardIds': [],
        'gpsTrail': [],
        'mockLocationDetected': false,
      });

  final wardA = ward('wa', 22.70);
  final wardB = ward('wb', 22.71);
  final wardC = ward('wc', 22.72);

  /// The overrides are typed `dynamic` because Riverpod 3.4 no longer
  /// exports the `Override` type to package consumers at all — the values
  /// are what `overrideWithValue/overrideWith` return.
  Future<void> pumpScreen(
    WidgetTester tester,
    List<dynamic> overrides, {
    List<dynamic> extra = const [],
  }) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          tileUrlTemplateProvider.overrideWithValue(null),
          // D1 owns the real van id at integration; tests pin the seeded demo
          // van (default provider throws — a wrong van must fail loudly).
          currentVanIdProvider.overrideWithValue('van-01'),
          ...overrides,
          ...extra,
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: LiveRouteScreen(),
        ),
      ),
    );
  }

  /// The fake streams resolve within a few microtask frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('data state: map, ordered ward rows, next chip on the first undone',
      (tester) async {
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider.overrideWithValue(FakeVansRepository([
          van(updatedAt: now.add(const Duration(seconds: 5))),
        ])),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([])),
        wardsRepositoryProvider.overrideWithValue(
            FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([route()])),
      ],
    );
    await settle(tester);

    // Map is up (tiles swapped out in tests — no network attempts).
    expect(find.byKey(const Key('liveRoute.map')), findsOneWidget);

    // AppBar shows the route name; placeholders present (tickets 09/08 slots).
    expect(find.text('Godhra Fort Route'), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.noticesPlaceholder')), findsOneWidget);
    expect(
        find.byKey(const Key('liveRoute.endTripPlaceholder')), findsOneWidget);

    // Ward list rows exist for every route ward, in route order (top-to-bottom).
    final rowOrder = [
      for (final swap in ['wa', 'wb', 'wc'])
        tester.getBottomRight(
            find.byKey(Key('liveRoute.wardRow.$swap'))).dy,
    ];
    expect(rowOrder[0] < rowOrder[1] && rowOrder[1] < rowOrder[2], isTrue,
        reason: 'rows must follow routes.wardIds order, not the load order');

    // "Next" chip sits in the first undone row, and nowhere earlier.
    expect(
      find.descendant(
        of: find.byKey(const Key('liveRoute.wardRow.wa')),
        matching: find.byKey(const Key('liveRoute.nextChip')),
      ),
      findsOneWidget,
      reason: 'first undone ward is the next in route order',
    );

    // Van marker present (own doc stream).
    expect(find.byKey(const Key('liveRoute.vanMarker')), findsOneWidget);
  });

  testWidgets('done ticks from trips.wardsDone of the open trip', (tester) async {
    final freshAt = now.add(const Duration(seconds: 2));
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider
            .overrideWithValue(FakeVansRepository([van(updatedAt: freshAt)])),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([
          tripFrom([
            {'wardId': 'wa', 'doneAt': now, 'flagged': false},
            {'wardId': 'wb', 'doneAt': now, 'flagged': true},
          ]),
        ])),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([route()])),
      ],
    );
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.doneTick.wb')), findsOneWidget);
    // Flagged Mark Ward Done stays visually recorded for the driver.
    expect(find.byKey(const Key('liveRoute.flagged.wb')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.doneTick.wc')), findsNothing);

    // Next highlight moved to the first undone ward.
    expect(
      find.descendant(
        of: find.byKey(const Key('liveRoute.wardRow.wc')),
        matching: find.byKey(const Key('liveRoute.nextChip')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('van doc stream updates the marker; stale fix shows the caption',
      (tester) async {
    final vans = FakeVansRepository([
      // Start stale: updated 2 min before "now".
      van(updatedAt: now.add(const Duration(minutes: -2))),
    ]);
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider
            .overrideWithValue(CountingVansRepository(vans)),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([])),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([route()])),
      ],
    );
    await settle(tester);

    // Stale → caption on the list panel; a fresh write through the same
    // stream drops it.
    expect(find.byKey(const Key('liveRoute.staleCaption')), findsOneWidget);
    await tester.runAsync(() => vans.updateLastLocation(
          vanId: 'van-01',
          lat: 22.7,
          lng: 73.7,
          speedKmph: 11,
        ));
    await settle(tester);
    expect(find.byKey(const Key('liveRoute.staleCaption')), findsNothing);
    // The follow-the-van camera move + marker rebuild take extra frames
    // after the fresh doc streams in.
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('liveRoute.vanMarker')), findsOneWidget);
  });

  testWidgets('trip stream: appendWardDone through the fake ticks the ward list',
      (tester) async {
    final trips = FakeTripsRepository([]); // no trip at first → nothing done.
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider
            .overrideWithValue(FakeVansRepository([van(updatedAt: now)])),
        tripsRepositoryProvider.overrideWithValue(trips),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([route()])),
      ],
    );
    await settle(tester);

    // No trip yet → nothing done, so no "next" marker until data settles...
    // (the first undone ward IS marked next even before a trip exists).
    expect(
      find.descendant(
        of: find.byKey(const Key('liveRoute.wardRow.wa')),
        matching: find.byKey(const Key('liveRoute.nextChip')),
      ),
      findsOneWidget,
    );
    // No done ticks yet.
    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsNothing);

    final created = await trips.createTrip(tripFrom([]));
    await settle(tester);
    await tester.runAsync(
        () => trips.appendWardDone(created.id, WardDone(
              wardId: 'wa',
              doneAt: now,
              flagged: false,
            )));
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('liveRoute.wardRow.wb')),
        matching: find.byKey(const Key('liveRoute.nextChip')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('offline override shows the banner over cached data', (tester) async {
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider.overrideWithValue(FakeVansRepository([
          van(updatedAt: now),
        ])),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([])),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([route()])),
      ],
      extra: [
        offlineStatusProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.offlineBanner')), findsOneWidget);
    // The route still renders from the (fake) cache — offline never blanks D2.
    expect(find.text('Godhra Fort Route'), findsOneWidget);
  });

  testWidgets('empty route (no wardIds) → empty state, not the map',
      (tester) async {
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider
            .overrideWithValue(FakeVansRepository([van(updatedAt: now)])),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([])),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider
            .overrideWithValue(FakeRoutesRepository([route(wardIds: [])])),
      ],
    );
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.empty')), findsOneWidget);
    expect(find.text('This route has no wards'), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.map')), findsNothing);
  });

  testWidgets('route doc missing → empty state with the not-found message',
      (tester) async {
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider
            .overrideWithValue(FakeVansRepository([van(updatedAt: now)])),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([])),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([])),
      ],
    );
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.empty')), findsOneWidget);
    expect(find.text('Route not found'), findsOneWidget);
  });

  testWidgets('stream error → error state with a retry button wired to the seam',
      (tester) async {
    await pumpScreen(
      tester,
      [
        vansRepositoryProvider.overrideWithValue(ThrowingVansRepository()),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([])),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([route()])),
      ],
    );
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.error')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.retry')), findsOneWidget);
    final retry = find.byKey(const Key('liveRoute.retry'));
    await tester.tap(retry);
    await settle(tester);
    // The retry invalidates and re-subscribes; still failed against the
    // throwing fake, but the screen must not crash.
    expect(find.byKey(const Key('liveRoute.error')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('0.11: autoDispose cancels the repository listeners on dispose',
      (tester) async {
    final realVans = FakeVansRepository([van(updatedAt: now)]);
    final counted = CountingVansRepository(realVans);
    final container = ProviderContainer(
      overrides: [
        currentVanIdProvider.overrideWithValue('van-01'),
        vansRepositoryProvider.overrideWithValue(counted),
        tripsRepositoryProvider.overrideWithValue(FakeTripsRepository([])),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider.overrideWithValue(FakeRoutesRepository([route()])),
      ],
    );
    addTearDown(container.dispose);

    // One screen mounted: the chain holds live listeners.
    container.listen(
      liveRouteStateProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    // Microtask-only pumping: tester.pump flushes microtasks AND advances
    // the fake clock. pumpEventQueue schedules REAL timers, which never
    // fire inside testWidgets' FakeAsync zone (it hangs the test — the
    // same wedge ticket 10 documented for awaited cancels).
    await tester.pump();
    await tester.pump();
    expect(counted.activeListeners, greaterThanOrEqualTo(1));

    // Dispose: listeners must go (0.11 — no lingering subscriptions).
    container.dispose();
    await tester.pump();
    await tester.pump();
    expect(counted.activeListeners, 0);
  });
}
