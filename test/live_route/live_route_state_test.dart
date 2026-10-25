/// Reducer tests for the D2 screen state (ticket 06): the pure
/// `combineLiveRouteState` over the repository AsyncValues — error, loading,
/// empty and data precedence plus the offline flag (spec user story 24).
library;

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/live_route/domain/live_route_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 9, 30);

  Van vanFromMap() => Van.fromMap({
        'id': 'van-01',
        'plateNo': 'GJ-05-AB-1234',
        'routeId': 'route-01',
        'status': 'on_shift',
        'lastLocation': {
          'lat': 22.7759,
          'lng': 73.7092,
          'updatedAt': now,
          'speedKmph': 12.5,
        },
        'currentTripId': 'trip-1',
        'batteryPct': 76,
      });

  RouteModel routeFromMap(List<String> wardIds) => RouteModel.fromMap({
        'id': 'route-01',
        'name': 'Godhra Fort Route',
        'wardIds': wardIds,
        'scheduledStartTime': '07:30',
      });

  Ward ward(String id) => Ward.fromMap({
        'id': id,
        'name': 'Ward $id',
        'nameGu': 'gu',
        'code': 'c-$id',
        'type': 'urban',
        'center': {'lat': 22.77, 'lng': 73.71},
        'radiusM': 400,
        'routeId': 'route-01',
        'inspectorId': 'staff-01',
        'escalationTo': 'staff-09',
      });

  final noVan = AsyncValue<Van?>.data(null);
  final noTrip = AsyncValue<Trip?>.data(null);
  final loadedRoute =
      AsyncValue<RouteModel?>.data(routeFromMap(['wa', 'wb', 'wc']));
  final loadedWards =
      AsyncValue<List<Ward>>.data([ward('wa'), ward('wb'), ward('wc')]);
  final pureLoading = AsyncValue<Van?>.loading();
  final erroredVan = AsyncValue<Van?>.error('boom', StackTrace.empty);
  final erroredRoute = AsyncValue<RouteModel?>.error('boom', StackTrace.empty);

  LiveRouteState combine({
    AsyncValue<Van?>? van,
    AsyncValue<Trip?>? trip,
    AsyncValue<RouteModel?>? route,
    AsyncValue<List<Ward>>? wards,
    required bool offline,
    DateTime? at,
  }) =>
      combineLiveRouteState(
        van: van ?? noVan,
        trip: trip ?? noTrip,
        route: route ?? loadedRoute,
        wards: wards ?? loadedWards,
        isOffline: offline,
        now: at ?? now,
      );

  LiveRouteData asData(LiveRouteState state) =>
      state is LiveRouteData ? state : (throw state);

  group('error / loading / empty precedence', () {
    test('fresh data without van fix → data, no marker, first ward next', () {
      final data = asData(combine(offline: false));
      expect(data.wardSteps.map((s) => s.ward.id), ['wa', 'wb', 'wc']);
      expect(data.vanMarker, isNull);
      expect(data.nextWard?.ward.id, 'wa');
      expect(data.isOffline, isFalse);
    });

    test('any stream error → one error state (no half-render)', () {
      expect(combine(van: erroredVan, offline: false), const LiveRouteError());
      expect(
        combine(route: erroredRoute, offline: false),
        const LiveRouteError(),
      );
    });

    test('loading with no value yet → loading', () {
      expect(combine(van: pureLoading, offline: false), const LiveRouteLoading());
    });

    test('missing route doc → empty (routeMissing)', () {
      expect(
        combine(route: AsyncValue<RouteModel?>.data(null), offline: false),
        const LiveRouteEmpty(LiveRouteEmptyReason.routeMissing),
      );
    });

    test('route with no wardIds → empty (noWards)', () {
      expect(
        combine(
            route: AsyncValue<RouteModel?>.data(routeFromMap([])),
            offline: false),
        const LiveRouteEmpty(LiveRouteEmptyReason.noWards),
      );
    });

    test('route ids resolving to no ward docs → empty (noWards)', () {
      expect(
        combine(
            route: AsyncValue<RouteModel?>.data(
                routeFromMap(['ghost-a', 'ghost-b'])),
            offline: false),
        const LiveRouteEmpty(LiveRouteEmptyReason.noWards),
      );
    });

    test('a null van doc is data with no marker (never loading/empty)', () {
      final data = asData(combine(offline: false));
      expect(data.vanMarker, isNull);
    });
  });

  group('ticks + next from the open trip', () {
    Trip trip(List<Map<String, Object?>> wardsDone) => Trip.fromMap({
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

    test('done set moves the next ward along; flagged kept', () {
      final data = asData(combine(
        trip: AsyncValue.data(trip([
          {'wardId': 'wa', 'doneAt': now, 'flagged': true},
          {'wardId': 'wb', 'doneAt': now, 'flagged': false},
        ])),
        offline: false,
      ));
      expect(data.doneCount, 2);
      expect(data.nextWard?.ward.id, 'wc');
      final wa = data.wardSteps.first;
      expect(wa.isDone, isTrue);
      expect(wa.isFlagged, isTrue);
    });

    test('trip done ids not on the route change nothing visible', () {
      final data = asData(combine(
        trip: AsyncValue.data(trip([
          {'wardId': 'ghost', 'doneAt': now, 'flagged': false},
        ])),
        offline: false,
      ));
      expect(data.doneCount, 0);
      expect(data.nextWard?.ward.id, 'wa');
    });

    test('fully-done route → data with no next highlight', () {
      final data = asData(combine(
        trip: AsyncValue.data(trip([
          {'wardId': 'wa', 'doneAt': now, 'flagged': false},
          {'wardId': 'wb', 'doneAt': now, 'flagged': false},
          {'wardId': 'wc', 'doneAt': now, 'flagged': false},
        ])),
        offline: false,
      ));
      expect(data.nextWard, isNull);
      expect(data.doneCount, 3);
    });

    test('duplicate route ids collapse to first occurrence (ruling 5)', () {
      final data = asData(combineLiveRouteState(
        van: noVan,
        trip: noTrip,
        route: AsyncValue.data(routeFromMap(['wa', 'wa', 'wb'])),
        wards: AsyncValue.data([ward('wa'), ward('wb')]),
        isOffline: false,
        now: now,
      ));
      expect(data.wardSteps.map((s) => s.ward.id), ['wa', 'wb']);
      expect(data.wardSteps.map((s) => s.orderIndex), [0, 1]);
    });
  });

  group('offline flag', () {
    test('offline=true travels into the data state (banner source)', () {
      expect(asData(combine(offline: true)).isOffline, isTrue);
    });
  });

  group('van marker in the data state', () {
    test('stale fix lands stale in the marker (grey + caption source)', () {
      final data = asData(combine(
        van: AsyncValue.data(vanFromMap()),
        offline: false,
        at: now.add(const Duration(seconds: 61)),
      ));
      expect(data.vanMarker, isNotNull);
      expect(data.vanMarker!.isStale, isTrue);
      expect(data.vanMarker!.minutesSinceUpdate, 1);
    });

    test('fresh fix is live', () {
      final data = asData(combine(
        van: AsyncValue.data(vanFromMap()),
        offline: false,
        at: now.add(const Duration(seconds: 5)),
      ));
      expect(data.vanMarker!.isStale, isFalse);
    });
  });
}
