/// Provider wiring test for the offline sync feature (F-D7, ticket 12):
/// proves the Riverpod graph in `offline_providers.dart` builds and that
/// `unsyncedPointsCountProvider` surfaces the count WITHOUT any platform
/// channel, Firestore or Hive — every collaborator overridden with a seam
/// fake (spec: seam 1 overrides).
library;

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repository_providers.dart';
import 'package:driverapp/features/tracking/domain/trail_buffer.dart';
import 'package:driverapp/features/tracking/offline/connectivity_source.dart';
import 'package:driverapp/features/tracking/offline/offline_providers.dart';
import 'package:driverapp/features/tracking/offline/offline_write_queue.dart';
import 'package:driverapp/features/tracking/tracking_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../repositories/fake_repositories.dart';

void main() {
  late FakeVansRepository fakeVans;
  late FakeTripsRepository fakeTrips;
  late _FakeConnectivity connectivity;
  late _MemoryQueue queue;
  late _FakeTrailBuffer trailBuffer;

  setUp(() {
    fakeVans = FakeVansRepository([
      Van(
        id: 'van-01',
        plateNo: 'MH-01',
        routeId: 'route-01',
        status: VanStatus.idle,
        lastLocation: null,
        currentTripId: 'trip-1',
        batteryPct: null,
      ),
    ]);
    fakeTrips = FakeTripsRepository([
      Trip(
        id: 'trip-1',
        vanId: 'van-01',
        routeId: 'route-01',
        driverId: '',
        wardIds: const <String>[],
        date: DateTime.utc(2026, 10, 24),
        startedAt: DateTime.utc(2026, 10, 24, 8),
        endedAt: null,
        wardsDone: const <WardDone>[],
        alertedWardIds: const <String>[],
        gpsTrail: const <GpsPoint>[],
        mockLocationDetected: false,
      ),
    ]);
    connectivity = _FakeConnectivity();
    queue = _MemoryQueue();
    trailBuffer = _FakeTrailBuffer();
  });

  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [
      vansRepositoryProvider.overrideWithValue(fakeVans),
      tripsRepositoryProvider.overrideWithValue(fakeTrips),
      connectivitySourceProvider.overrideWithValue(connectivity),
      offlineWriteQueueProvider.overrideWithValue(queue),
      trailBufferFactoryProvider.overrideWithValue(
        (tripId) async => trailBuffer,
      ),
    ],
  );

  test(
    'count starts at 0, rises with attached pending points, drains to 0',
    () async {
      // Backlog BEFORE the service resolves: 1 queued lastLocation + 2 trail
      // points (the state a dead zone would leave after an app restart).
      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6780,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: DateTime.utc(2026, 10, 24, 8),
      );
      await trailBuffer.add(
        GpsPoint(lat: 22.60, lng: 77.0, t: DateTime.utc(2026, 10, 24, 8)),
      );
      await trailBuffer.add(
        GpsPoint(lat: 22.601, lng: 77.0, t: DateTime.utc(2026, 10, 24, 8, 1)),
      );

      final container = buildContainer();
      addTearDown(container.dispose);

      // Attach BEFORE subscribing: the count includes the trail backlog
      // only for the attached trip (the state after restart + resume).
      final sync = container.read(offlineSyncServiceProvider);
      sync.attachTrip('trip-1');

      final values = <int>[];
      container.listen(
        unsyncedPointsCountProvider,
        (previous, next) => next.whenData(values.add),
      );
      await container
          .read(unsyncedPointsCountProvider.future)
          .then((count) => expect(count, 3));
      expect(values, [3]); // late subscriber sees the CURRENT count first

      // The sync drains everything (fake repositories accept the writes).
      await sync.flushNow();
      await pumpEventQueue();

      expect(values, [3, 2, 0]); // ticks down as each flush succeeds
      expect(fakeVans.vans['van-01']!.lastLocation!.lat, 22.6780);
      expect(fakeTrips.trips['trip-1']!.gpsTrail, hasLength(2));
    },
  );
}

// ---------------------------------------------------------------------------
// seam fakes (local: queue + trail buffer + connectivity)
// ---------------------------------------------------------------------------

class _FakeConnectivity implements ConnectivitySource {
  @override
  Stream<bool> get status => const Stream<bool>.empty();
}

class _MemoryQueue implements OfflineWriteQueue {
  QueuedLastLocation? _item;

  @override
  Future<void> enqueueLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    required DateTime recordedAt,
  }) async {
    _item = QueuedLastLocation(
      vanId: vanId,
      lat: lat,
      lng: lng,
      speedKmph: speedKmph,
      recordedAt: recordedAt,
    );
  }

  @override
  Future<QueuedLastLocation?> takeLastLocation() async {
    final item = _item;
    _item = null;
    return item;
  }

  @override
  Future<void> putBackLastLocation(QueuedLastLocation item) async {
    _item = item;
  }

  @override
  Future<int> get pendingLastLocationCount async => _item == null ? 0 : 1;
}

class _FakeTrailBuffer implements TrailBuffer {
  final List<GpsPoint> _points = <GpsPoint>[];

  @override
  int get pendingCount => _points.length;

  @override
  Future<void> add(GpsPoint point) async => _points.add(point);

  @override
  Future<List<GpsPoint>> takeOldest({int? limit}) async {
    final take = List<GpsPoint>.of(_points);
    _points.clear();
    return take;
  }

  @override
  Future<void> putBackOldest(List<GpsPoint> points) async =>
      _points.insertAll(0, points);
}
