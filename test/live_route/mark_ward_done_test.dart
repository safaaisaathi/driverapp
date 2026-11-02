/// Mark Ward Done tests (ticket 07, spec seam 1 + the domain flag decision
/// through the state the screen already watches).
///
/// The full D2 screen runs under a `ProviderScope` whose repository
/// providers are the seam fakes — no platform channels, tiles swapped out.
/// The done tick and the next-chip move come purely from the open-trip
/// stream ("state you already watch; no local caching of done"), so the
/// fake's re-emission after `appendWardDone` is what proves the write —
/// no assertion reads a "done" flag out of any local state.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:driverapp/core/l10n/app_localizations.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/core/theme/app_theme.dart';
import 'package:driverapp/core/widgets/pill_nav.dart';
import 'package:driverapp/features/live_route/live_route_providers.dart';
import 'package:driverapp/features/live_route/live_route_screen.dart';
import 'package:driverapp/features/live_route/mark_ward_done_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../repositories/fake_repositories.dart';

void main() {
  // Real clock: the open-trip watch filters by TODAY's calendar day (same
  // lesson as live_route_widget_test.dart — seeded trips must carry today's
  // date to be found).
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

  RouteModel route() => RouteModel.fromMap({
        'id': 'route-01',
        'name': 'Godhra Fort Route',
        'wardIds': ['wa', 'wb', 'wc'],
        'scheduledStartTime': '07:30',
      });

  /// [vanLat] at a ward centre's latitude puts the van inside that ward's
  /// 400 m radius (~55 m at +0.0005 deg); the default 22.7759 sits ~8 km
  /// from every ward — outside, flagged-decision territory.
  Van van({double vanLat = 22.7759, bool withFix = true}) => Van.fromMap({
        'id': 'van-01',
        'plateNo': 'GJ-05-AB-1234',
        'routeId': 'route-01',
        'status': 'on_shift',
        'lastLocation': withFix
            ? {
                'lat': vanLat,
                'lng': 73.71,
                'updatedAt': now,
                'speedKmph': 11.0,
              }
            : null,
        'currentTripId': null,
        'batteryPct': 76,
      });

  /// Today's open trip with an empty `wardsDone` (fresh shift).
  Trip emptyTrip() => Trip.fromMap({
        'id': 'trip-1',
        'vanId': 'van-01',
        'routeId': 'route-01',
        'date': now,
        'startedAt': now,
        'endedAt': null,
        'wardsDone': [],
        'alertedWardIds': [],
        'gpsTrail': [],
        'mockLocationDetected': false,
      });

  /// Today's open trip whose 0.16 scope is the FIRST route ward only — the
  /// driver was allotted `wa` alone while the route still lists three.
  Trip scopedTrip() => Trip.fromMap({
        'id': 'trip-1',
        'vanId': 'van-01',
        'routeId': 'route-01',
        'driverId': 'AB-1234',
        'wardIds': ['wa'],
        'date': now,
        'startedAt': now,
        'endedAt': null,
        'wardsDone': [],
        'alertedWardIds': [],
        'gpsTrail': [],
        'mockLocationDetected': false,
      });

  /// Today's open trip of a 0.16 driver with NO allotted ward — the empty
  /// allotment is authoritative (it never widens back to the route).
  Trip emptyAllotmentTrip() => Trip.fromMap({
        'id': 'trip-1',
        'vanId': 'van-01',
        'routeId': 'route-01',
        'driverId': 'AB-1234',
        'wardIds': [],
        'date': now,
        'startedAt': now,
        'endedAt': null,
        'wardsDone': [],
        'alertedWardIds': [],
        'gpsTrail': [],
        'mockLocationDetected': false,
      });

  final wardA = ward('wa', 22.70);
  final wardB = ward('wb', 22.71);
  final wardC = ward('wc', 22.72);

  Future<void> pumpScreen(
    WidgetTester tester,
    List<dynamic> overrides, {
    List<dynamic> extra = const [],
    // The real offline default reads connectivity_plus (platform channel);
    // every test pins it here so no test reaches the plugin.
    bool offline = false,
  }) {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          tileUrlTemplateProvider.overrideWithValue(null),
          offlineStatusProvider.overrideWith((ref) => Stream.value(offline)),
          ...overrides,
          ...extra,
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: LiveRouteScreen(vanId: 'van-01'),
        ),
      ),
    );
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Pulls the sheet to its FULL snap — the driver's "open the drawer"
  /// gesture. The sheet now opens COLLAPSED (bottom-most: the head card and
  /// the mark control hide BEHIND the pill nav by design, device pass
  /// 2026-10-28), so nothing inside the panel is reachable until pulled up.
  /// The drag starts on the grab strip — the only chrome visible above the
  /// pill nav — because a drag at the scrollable's centre would land on the
  /// nav overlay and be swallowed.
  Future<void> pullSheetFull(WidgetTester tester) async {
    final navTop = tester.getRect(find.byType(PillNav)).top;
    await tester.dragFrom(
      Offset(tester.getCenter(find.byType(Scrollable)).dx, navTop - 18),
      const Offset(0, -900),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// Scrolls until the finder's centre sits ABOVE the pill nav band.
  /// scrollUntilVisible only guarantees visibility inside the scroll view —
  /// and the view's bottom 96 dp sit under the floating nav where taps die
  /// (2026-10-28 device-session defect: nav container occupies 804–884 of a
  /// 900 dp window).
  Future<void> scrollAboveNav(
    WidgetTester tester,
    Finder finder, {
    double step = 72,
  }) async {
    await pullSheetFull(tester);
    final navTop = tester.getRect(find.byType(PillNav)).top;
    await tester.scrollUntilVisible(
      finder,
      step,
      scrollable: find.byType(Scrollable),
    );
    for (
      var i = 0;
      i < 10 && tester.getRect(finder).center.dy >= navTop;
      i++
    ) {
      await tester.drag(find.byType(Scrollable), Offset(0, -step));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  FakeVansRepository vansFor(double vanLat, {bool withFix = true}) =>
      FakeVansRepository([van(vanLat: vanLat, withFix: withFix)]);

  List<dynamic> standardOverrides(
    FakeTripsRepository trips, {
    double vanLat = 22.7759,
    bool withFix = true,
  }) =>
      [
        vansRepositoryProvider
            .overrideWithValue(vansFor(vanLat, withFix: withFix)),
        tripsRepositoryProvider.overrideWithValue(trips),
        wardsRepositoryProvider
            .overrideWithValue(FakeWardsRepository([wardA, wardB, wardC])),
        routesRepositoryProvider
            .overrideWithValue(FakeRoutesRepository([route()])),
      ];

  testWidgets(
      'big next-ward button, inside radius: appends exactly {wardId, doneAt, '
      'flagged:false} for ONLY the tapped ward; tick + chip move purely from '
      'the trip stream', (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
    await settle(tester);
    await pullSheetFull(tester);

    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await settle(tester);

    // The write went through the seam: exactly one entry, exactly the
    // tapped ward, exactly the contract shape.
    final raw = trips.trips['trip-1']!.toMap()['wardsDone'] as List<Object?>;
    expect(raw, hasLength(1));
    final entry = raw.first as Map<Object?, Object?>;
    expect(entry.keys.toSet(),
        unorderedEquals(<String>['wardId', 'doneAt', 'flagged']));
    expect(entry['wardId'], 'wa');
    expect(entry['flagged'], isFalse, reason: 'inside 400 m → not flagged');
    final doneAt = (entry['doneAt'] as Timestamp).toDate();
    expect(doneAt.difference(now).abs(), lessThan(const Duration(minutes: 1)));

    // UI proof is the STREAM state, not any local flag.
    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('liveRoute.wardRow.wb')),
        matching: find.byKey(const Key('liveRoute.nextChip')),
      ),
      findsOneWidget,
      reason: 'next highlight advances to the first undone ward',
    );
  });

  testWidgets('small control on an OUT-OF-ORDER undone ward appends only '
      'that ward, flagged outside the radius, next chip stays on the first '
      'undone', (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7759));
    await settle(tester);

    // Out of order: the third ward through its own smaller control. The 72
    // dp rows scroll in the sheet — bring wc's row clear of the nav before
    // tapping it.
    await scrollAboveNav(tester, find.byKey(const Key('liveRoute.markWard.wc')));
    await tester.tap(find.byKey(const Key('liveRoute.markWard.wc')));
    await settle(tester);

    final raw = trips.trips['trip-1']!.toMap()['wardsDone'] as List<Object?>;
    expect(raw, hasLength(1));
    final entry = raw.first as Map<Object?, Object?>;
    expect(entry['wardId'], 'wc');
    expect(entry['flagged'], isTrue,
        reason: 'van is outside every ward here → flagged, still allowed');
    expect(find.byKey(const Key('liveRoute.doneTick.wc')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsNothing);
    // Next chip did NOT move: wc was marked out of order.
    expect(
      find.descendant(
        of: find.byKey(const Key('liveRoute.wardRow.wa')),
        matching: find.byKey(const Key('liveRoute.nextChip')),
      ),
      findsOneWidget,
    );
  });

  testWidgets('out-of-radius mark from the big NEXT button is allowed and '
      'flagged on that entry only (PRD: still allow, set flagged)',
      (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7759));
    await settle(tester);
    await pullSheetFull(tester);

    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await settle(tester);

    final raw = trips.trips['trip-1']!.toMap()['wardsDone'] as List<Object?>;
    expect(raw, hasLength(1));
    final entry = raw.first as Map<Object?, Object?>;
    expect(entry['wardId'], 'wa');
    expect(entry['flagged'], isTrue);
    // Only that entry is flagged: no tick flags elsewhere.
    expect(find.byKey(const Key('liveRoute.flagged.wa')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.flagged.wb')), findsNothing);
    expect(find.byKey(const Key('liveRoute.flagged.wc')), findsNothing);
  });

  testWidgets('inside-radius mark from the big NEXT button is unflagged',
      (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
    await settle(tester);
    await pullSheetFull(tester);

    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.flagged.wa')), findsNothing);
  });

  testWidgets('no position fix yet: the mark still lands, conservatively '
      'flagged for admin review (flagged is the review channel, never '
      'silently "inside")', (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(
      tester,
      standardOverrides(trips, vanLat: 22.7759, withFix: false),
    );
    await settle(tester);
    await pullSheetFull(tester);

    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await settle(tester);

    final raw = trips.trips['trip-1']!.toMap()['wardsDone'] as List<Object?>;
    expect(raw, hasLength(1));
    expect((raw.first as Map<Object?, Object?>)['flagged'], isTrue);
    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsOneWidget);
  });

  testWidgets('double-tap idempotency (ruling 13): taps in-flight and after '
      'the write landed never duplicate the entry', (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
    await settle(tester);
    await pullSheetFull(tester);

    // Same-storm taps (no settle between): the in-flight guard eats the
    // second tap.
    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await settle(tester);
    // After the write landed, wa is DONE — its button is gone; the ONE
    // pinned big button (§4.17) now targets wb, so wa can never be appended
    // again through the UI either.
    expect(find.byKey(const Key('liveRoute.markWard.wa')), findsNothing);
    expect(find.byKey(const Key('liveRoute.markNextWard')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('liveRoute.wardRow.wb')),
        matching: find.byKey(const Key('liveRoute.nextChip')),
      ),
      findsOneWidget,
    );

    final raw = trips.trips['trip-1']!.toMap()['wardsDone'] as List<Object?>;
    expect(raw, hasLength(1), reason: 'client dedupes by wardId (ruling 13)');
    expect((raw.single as Map<Object?, Object?>)['wardId'], 'wa');
  });

  testWidgets('no open trip: the mark controls disable with a hint and '
      'nothing is written', (tester) async {
    final trips = FakeTripsRepository([]); // no trip doc at all
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
    await settle(tester);

    final bigButton = tester.widget<FilledButton>(
        find.byKey(const Key('liveRoute.markNextWard')));
    expect(bigButton.onPressed, isNull, reason: 'no trip to append into');
    final smallButton = tester
        .widget<IconButton>(find.byKey(const Key('liveRoute.markWard.wb')));
    expect(smallButton.onPressed, isNull);
    expect(find.byKey(const Key('liveRoute.markNoTripHint')), findsOneWidget);

    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')),
        warnIfMissed: false);
    await settle(tester);
    expect(trips.trips, isEmpty,
        reason: 'writing without an open trip must not happen');
  });

  testWidgets('offline: the write still goes through (PRD offline: local '
      'write, sync later) and no failure shows', (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(
      tester,
      standardOverrides(trips, vanLat: 22.7005),
      offline: true,
    );
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.offlineBanner')), findsOneWidget);
    await pullSheetFull(tester);
    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await settle(tester);

    final raw = trips.trips['trip-1']!.toMap()['wardsDone'] as List<Object?>;
    expect(raw, hasLength(1), reason: 'offline never blocks the mark');
    expect(find.byKey(const Key('liveRoute.markError')), findsNothing);
  });

  testWidgets('write failure: a boring message appears, no tick caches '
      'locally, and the screen stays out of the global error state',
      (tester) async {
    final trips = _ThrowingTripsRepository([emptyTrip()]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
    await settle(tester);
    await pullSheetFull(tester);

    await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.markError')), findsOneWidget);
    expect(find.text("Couldn't record. Try again."), findsOneWidget);
    // Nothing was written and NOTHING is cached done — the list keeps
    // rendering from the stream alone.
    expect(trips.trips['trip-1']!.wardsDone, isEmpty);
    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsNothing);
    expect(find.byKey(const Key('liveRoute.error')), findsNothing,
        reason: 'a failed mark is not a failed screen');
  });

  testWidgets('the big button target is ≥ 56 dp (contract section 6, '
      'one-handed)', (tester) async {
    final trips = FakeTripsRepository([emptyTrip()]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
    await settle(tester);

    final size =
        tester.getSize(find.byKey(const Key('liveRoute.markNextWard')));
    expect(size.height, greaterThanOrEqualTo(55.9));
  });

  testWidgets('route complete: no mark control for any ward', (tester) async {
    final rawTrip = emptyTrip().toMap()
      ..['wardsDone'] = <Object?>[
        _doneEntry('wa'),
        _doneEntry('wb'),
        _doneEntry('wc'),
      ];
    final trips = FakeTripsRepository([Trip.fromMap(rawTrip)]);
    await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
    await settle(tester);

    expect(find.byKey(const Key('liveRoute.markNextWard')), findsNothing);
    expect(find.byKey(const Key('liveRoute.markWard.wa')), findsNothing);
    expect(find.byKey(const Key('liveRoute.markWard.wb')), findsNothing);
    expect(find.byKey(const Key('liveRoute.markWard.wc')), findsNothing);
    // All ticked from the stream, no failure or hint noise.
    expect(find.byKey(const Key('liveRoute.doneTick.wa')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.doneTick.wb')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.doneTick.wc')), findsOneWidget);
    expect(find.byKey(const Key('liveRoute.markError')), findsNothing);
    expect(find.byKey(const Key('liveRoute.markNoTripHint')), findsNothing);
  });

  group('0.16 trip wardIds scope (D2 scopes map + marking to the trip)', () {
    testWidgets('a route ward outside the trip scope never renders (no map '
        'marker, no list row, no mark control)', (tester) async {
      final trips = FakeTripsRepository([scopedTrip()]);
      await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
      await settle(tester);
      await pullSheetFull(tester);

      // The trip's allotted ward is there...
      expect(find.byKey(const Key('liveRoute.wardRow.wa')), findsOneWidget);
      expect(find.byKey(const Key('liveRoute.wardMarker.wa')), findsOneWidget);
      // ...and the route's other wards are NOT (the map and the list both
      // follow the trip's scope, not `routes.wardIds`).
      expect(find.byKey(const Key('liveRoute.wardRow.wb')), findsNothing);
      expect(find.byKey(const Key('liveRoute.wardRow.wc')), findsNothing);
      expect(find.byKey(const Key('liveRoute.wardMarker.wb')), findsNothing);
      expect(find.byKey(const Key('liveRoute.wardMarker.wc')), findsNothing);
      expect(find.byKey(const Key('liveRoute.markWard.wb')), findsNothing);
      expect(find.byKey(const Key('liveRoute.markWard.wc')), findsNothing);
    });

    testWidgets('the next-ward button marks the trip-scope ward, not a '
        'route ward outside it', (tester) async {
      final trips = FakeTripsRepository([scopedTrip()]);
      await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
      await settle(tester);
      await pullSheetFull(tester);

      await tester.tap(find.byKey(const Key('liveRoute.markNextWard')));
      await settle(tester);

      final raw = trips.trips['trip-1']!.toMap()['wardsDone'] as List<Object?>;
      expect(raw, hasLength(1));
      expect((raw.single as Map<Object?, Object?>)['wardId'], 'wa');
    });

    testWidgets('a ward outside the trip scope is never written, even when '
        'the flow is asked directly', (tester) async {
      final trips = FakeTripsRepository([scopedTrip()]);
      await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
      await settle(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveRouteScreen)),
      );
      await container
          .read(markWardDoneFlowProvider.notifier)
          .mark('van-01', 'wb');
      await settle(tester);

      expect(trips.trips['trip-1']!.wardsDone, isEmpty,
          reason: 'the write path is scoped to the trip too');
      expect(find.byKey(const Key('liveRoute.markError')), findsOneWidget);
    });

    testWidgets('a 0.16 trip with NO allotted ward marks nothing (an empty '
        'allotment is authoritative, never the whole route)', (tester) async {
      final trips = FakeTripsRepository([emptyAllotmentTrip()]);
      await pumpScreen(tester, standardOverrides(trips, vanLat: 22.7005));
      await settle(tester);

      // The screen shows the empty state — no ward renders at all.
      expect(find.byKey(const Key('liveRoute.empty')), findsOneWidget);
      expect(find.byKey(const Key('liveRoute.wardRow.wa')), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(LiveRouteScreen)),
      );
      await container
          .read(markWardDoneFlowProvider.notifier)
          .mark('van-01', 'wa');
      await settle(tester);

      expect(trips.trips['trip-1']!.wardsDone, isEmpty);
    });
  });
}

/// One `trips.wardsDone` entry map for seeding (0.2 shape).
Map<String, Object?> _doneEntry(String wardId) => {
      'wardId': wardId,
      'doneAt': dateTimeToDocTime(DateTime.now()),
      'flagged': false,
    };

/// A trips fake whose append ALWAYS fails — the watch stream itself stays
/// healthy, proving a write failure surfaces WITHOUT tripping the screen's
/// global error state (time-only: no tick appears).
class _ThrowingTripsRepository extends FakeTripsRepository {
  _ThrowingTripsRepository([super.seed]);

  @override
  Future<void> appendWardDone(String tripId, WardDone entry) async {
    throw Exception('dead-zone write');
  }
}
