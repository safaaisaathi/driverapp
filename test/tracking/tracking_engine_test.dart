/// Tracking engine tests (ticket 05): engine against seam fakes only — no
/// platform channels, no Firestore (spec Testing Decisions: seam 1 =
/// repositories via fake_repositories; the real Write Policy code runs).
///
/// Covers F-D2 + F-D8 acceptances that don't need a device: policy-driven
/// writes, trail buffering/batching order, resume reattach, stop-flush,
/// service-failure states, and the Flow F revive (offline → on_shift on
/// next write). Real-device behaviour (permissions, service survival) is
/// ticket 14. F-D9 (ticket 11): the mock/real intake hook latches
/// `trips.mockLocationDetected` exactly once per trip run.
///
/// Timer tests run on REAL timers with the test-only cadence overrides
/// (`checkIntervalSec: 1`) instead of fakeAsync: fakeAsync cannot pump the
/// async/await resumptions the engine's write chains use (learned the hard
/// way), and real 1-second ticks are simple and sufficient.
library;

import 'dart:async';

import 'package:driverapp/core/domain/geo_point.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/tracking/domain/battery_source.dart';
import 'package:driverapp/features/tracking/domain/foreground_service.dart';
import 'package:driverapp/features/tracking/domain/position_fix.dart';
import 'package:driverapp/features/tracking/domain/position_source.dart';
import 'package:driverapp/features/tracking/domain/tracking_engine.dart';
import 'package:driverapp/features/tracking/domain/trail_buffer.dart';
import 'package:driverapp/features/tracking/offline/offline_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../repositories/fake_repositories.dart';

/// The trips fake plus a call recorder: the latch acceptance is "the write
/// happens at most once" — a doc-field read alone can't see repeat writes.
class _RecordingTripsRepository extends FakeTripsRepository {
  _RecordingTripsRepository([super.seed]);

  /// Every `setMockLocationDetected` call, in order (latch ⇒ one call).
  final List<bool> mockWrites = <bool>[];

  @override
  Future<void> setMockLocationDetected(
    String tripId, {
    required bool detected,
  }) async {
    mockWrites.add(detected);
    await super.setMockLocationDetected(tripId, detected: detected);
  }
}

void main() {
  // ---------------------------------------------------------------- fakes
  late FakeVansRepository vans;
  late _RecordingTripsRepository trips;
  late _FakePositions positions;
  late _FakeBattery battery;
  late _FakeService service;
  var clock = DateTime.utc(2026, 10, 24, 8); // fixed fake clock

  Van van(
    String id, {
    VanStatus status = VanStatus.idle,
    String? tripId,
    GeoPoint? depot,
  }) =>
      Van(
        id: id,
        plateNo: 'MH-01',
        routeId: 'route-01',
        status: status,
        lastLocation: null,
        currentTripId: tripId,
        batteryPct: null,
        depot: depot,
      );

  VanFix fixAt(double lat, {double lng = 77.0}) =>
      VanFix(lat: lat, lng: lng, speedKmph: 12, t: clock);

  /// One full cadence with margin (check interval overridden to 1 s).
  Future<void> oneTick() => Future<void>.delayed(
        const Duration(milliseconds: 1400),
      );

  /// The buffer the last [buildEngine] start opened — lets a test seed a
  /// backlog and inspect what each flush took (issue #13).
  _FakeTrailBuffer? lastBuffer;

  TrackingEngine buildEngine({
    int check = 1,
    int? flush,
    void Function(String tripId)? onAutoEnd,
  }) =>
      TrackingEngine(
        vansRepository: vans,
        tripsRepository: trips,
        positionSource: positions,
        batterySource: battery,
        serviceHandle: service,
        trailBufferFactory: (tripId) async =>
            lastBuffer = _FakeTrailBuffer(),
        clock: () => clock,
        checkIntervalSec: check,
        flushIntervalSec: flush,
        onShiftAutoEnded: onAutoEnd,
      );

  setUp(() {
    vans = FakeVansRepository([van('van-01')]);
    trips = _RecordingTripsRepository([
      // The engine never creates trips — the trip doc exists before the
      // engine starts (Start Shift / D1 creates it; ticket 04).
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
    positions = _FakePositions();
    battery = _FakeBattery(80);
    service = _FakeService();
  });

  // -------------------------------------------------- non-timer behaviour
  group('start()', () {
    test('service failure → failed outcome, no position subscription',
        () async {
      service.failNext();
      final engine = buildEngine();

      final result = await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'Tracking active',
        notificationBody: '',
      );

      expect(result.outcome, TrackingStartOutcome.serviceStartFailed);
      expect(engine.state.status, TrackingRunStatus.failed);
      expect(positions.distanceFilterM, isNull);
    });

    test('success → running, position filter = MIN_MOVE_M', () async {
      final engine = buildEngine();
      final result = await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'Tracking active',
        notificationBody: '',
      );

      expect(result.isStarted, isTrue);
      expect(engine.state.status, TrackingRunStatus.running);
      expect(engine.state.tripId, 'trip-1');
      expect(engine.state.vanId, 'van-01');
      expect(positions.distanceFilterM, 15); // minMoveM (0.4)
    });

    test('already running → alreadyRunning, no second service start',
        () async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );
      final count = service.startCount;

      final again = await engine.start(
        tripId: 'trip-2',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      expect(again.outcome, TrackingStartOutcome.alreadyRunning);
      expect(service.startCount, count);

      await engine.stop(); // no timer leak across tests
    });
  });

  group('resume (startForActiveShift)', () {
    test('open shift → resumed on the SAME trip, no new trip doc', () async {
      vans = FakeVansRepository([
        van('van-01', status: VanStatus.onShift, tripId: 'trip-9'),
      ]);
      final engine = buildEngine();

      final result = await engine.startForActiveShift(
        vanId: 'van-01',
        notificationTitle: 'Tracking active',
        notificationBody: '',
      );

      expect(result.isResumed, isTrue);
      expect(result.tripId, 'trip-9');
      expect(engine.state.tripId, 'trip-9');
      expect(trips.trips['trip-9'], isNull); // no duplicate trip created

      await engine.stop();
    });

    test('van idle / no currentTripId → notResumed', () async {
      final engine = buildEngine();

      final result = await engine.startForActiveShift(
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      expect(result.isResumed, isFalse);
      expect(engine.state.status, TrackingRunStatus.idle);
      expect(positions.distanceFilterM, isNull);
    });
  });

  // ------------------------------------------------ timer-driven cadence
  group('write policy cadence', () {
    test('first fix always writes lastLocation + battery', () async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780));
      await oneTick();

      final written = vans.vans['van-01']!.lastLocation;
      expect(written?.lat, 22.6780);
      expect(written?.lng, 77.0);
      expect(written?.speedKmph, 12);
      expect(vans.vans['van-01']!.batteryPct, 80);

      await engine.stop();
    });

    test('stationary van inside heartbeat window → skipped', () async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780));
      await oneTick();
      final afterFirst = vans.vans['van-01']!.lastLocation;
      expect(afterFirst, isNotNull);

      // Same position again: no minMoveM movement, no heartbeat yet.
      positions.emit(fixAt(22.6780));
      await oneTick();

      expect(vans.vans['van-01']!.lastLocation, afterFirst);

      await engine.stop();
    });

    test('moved ≥ minMoveM before heartbeat → writes', () async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780));
      await oneTick();

      // ~19 m north (> minMoveM of 15 m) within the heartbeat window.
      positions.emit(fixAt(22.67817));
      await oneTick();

      expect(
        vans.vans['van-01']!.lastLocation!.lat,
        closeTo(22.67817, 1e-9),
      );

      await engine.stop();
    });

    test('low battery switches the NEXT cadence to 30 s (F-D8)', () async {
      battery.value = 10; // below lowBatteryPct (20)
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );
      expect(engine.state.lowBatteryInterval, isFalse);

      positions.emit(fixAt(22.6780));
      await oneTick();

      expect(engine.state.lowBatteryInterval, isTrue);

      await engine.stop();
    });
  });

  group('trail batching', () {
    test('buffered points drain in trail order on flush ticks', () async {
      final engine = buildEngine(flush: 3);
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780));
      await oneTick(); // tick@1 writes + buffers A
      expect(trips.trips['trip-1']!.gpsTrail, isEmpty); // not flushed yet

      positions.emit(fixAt(22.67817)); // ~19 m move → accepted at next tick
      await oneTick(); // tick@2 writes + buffers B

      // Outcome-based drain wait (Bug Bag fix 2026-10-29): a loaded CI box
      // can slip a write resumption past the t=3 s flush tick, so the old
      // fixed 900 ms settle raced the timers in event-loop FIFO order.
      // The CONTRACT under test is the drain ORDER, not which tick lands
      // it: poll until both points are in, bounded.
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (trips.trips['trip-1']!.gpsTrail.length < 2) {
        if (DateTime.now().isAfter(deadline)) {
          fail('trail did not drain within 10 s (flush ticks stalled?)');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }

      final trail = trips.trips['trip-1']!.gpsTrail;
      expect(trail.length, 2);
      expect(trail.first.lat, 22.6780);
      expect(trail.last.lat, closeTo(22.67817, 1e-9));

      await engine.stop();
    });

    test('one flush carries at most maxTrailBatchPoints, oldest first, and '
        'stop() drains the rest (issue #13)', () async {
      final engine = buildEngine(flush: 5);
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      final buffer = lastBuffer!;
      final base = DateTime.utc(2026, 10, 24, 8);
      for (var i = 0; i < 2500; i++) {
        await buffer.add(
          GpsPoint(lat: i.toDouble(), lng: 77, t: base.add(Duration(seconds: i))),
        );
      }
      expect(buffer.pendingCount, 2500);

      // Wait for the FIRST flush tick only (5 s cadence; the fake write is
      // instant, so the window to assert is wide).
      final deadline = DateTime.now().add(const Duration(seconds: 15));
      while (trips.trips['trip-1']!.gpsTrail.isEmpty) {
        if (DateTime.now().isAfter(deadline)) fail('no flush within 15 s');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }

      final first = trips.trips['trip-1']!.gpsTrail;
      expect(first.length, maxTrailBatchPoints);
      expect(first.first.lat, 0);
      expect(first.last.lat, maxTrailBatchPoints - 1);
      expect(buffer.pendingCount, 2500 - maxTrailBatchPoints);

      // End Shift drains the backlog in further measured batches, order kept.
      await engine.stop();
      final all = trips.trips['trip-1']!.gpsTrail;
      expect(all.length, 2500);
      expect(all.first.lat, 0);
      expect(all.last.lat, 2499);
    });

    test('stop() performs the FINAL flush (End Shift semantics)', () async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780));
      await oneTick(); // written + buffered, not flushed (flush at 30 s)

      await engine.stop(); // final flush

      expect(trips.trips['trip-1']!.gpsTrail.length, 1);
      expect(engine.state.status, TrackingRunStatus.idle);
    });

    test('stop() twice is a no-op', () async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780));
      await oneTick();

      await engine.stop();
      final lengthAtStop = trips.trips['trip-1']!.gpsTrail.length;

      await engine.stop(); // must not throw, must not re-flush

      expect(trips.trips['trip-1']!.gpsTrail.length, lengthAtStop);
      expect(engine.state.status, TrackingRunStatus.idle);
    });

    test('stop() stops the foreground service — End Shift must not leave the '
        'persistent notification behind (P0 audit fix)', () async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );
      expect(service.startCount, 1);
      expect(service.stopCount, 0);

      await engine.stop();

      expect(service.stopCount, 1);
      // Idempotent: a second stop does not stop the service again.
      await engine.stop();
      expect(service.stopCount, 1);
    });
  });

  group('Flow F revive', () {
    test('backend-marked offline van → next write sets on_shift again',
        () async {
      // Seed the van ALREADY offline: the engine's doc watch reads this on
      // subscribe (what vanOfflineWatch's marking looks like mid-shift).
      vans = FakeVansRepository([
        van('van-01', status: VanStatus.offline, tripId: 'trip-1'),
      ]);
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780));
      await oneTick();

      expect(vans.vans['van-01']!.status, VanStatus.onShift);

      await engine.stop();
    });
  });

  // ---------------------------------------------------------------- F-D9
  group('mock-location latch (ticket 11 / F-D9)', () {
    VanFix mockAt(double lat) =>
        VanFix(lat: lat, lng: 77.0, speedKmph: 12, t: clock, isMocked: true);

    Future<TrackingEngine> runEngine() async {
      final engine = buildEngine();
      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );
      return engine;
    }

    test('one mock fix latches trips.mockLocationDetected = true', () async {
      final engine = await runEngine();

      positions.emit(mockAt(22.6780));
      await oneTick();

      expect(trips.mockWrites, [true]); // set through the repository seam
      expect(trips.trips['trip-1']!.mockLocationDetected, isTrue);

      await engine.stop();
    });

    test('many mock fixes → the write happens ONCE (local latch)', () async {
      final engine = await runEngine();

      positions.emit(mockAt(22.6780));
      await oneTick();
      positions.emit(mockAt(22.67817));
      await oneTick();
      positions.emit(mockAt(22.6783));
      await oneTick();

      expect(trips.mockWrites, hasLength(1)); // never re-written per fix
      await engine.stop();
    });

    test('real fixes never set the field', () async {
      final engine = await runEngine();

      positions.emit(fixAt(22.6780)); // real (isMocked defaults false)
      await oneTick();
      positions.emit(fixAt(22.67817));
      await oneTick();

      expect(trips.mockWrites, isEmpty);
      expect(trips.trips['trip-1']!.mockLocationDetected, isFalse);

      await engine.stop();
    });

    test('latch persists across later REAL fixes (never unset)', () async {
      final engine = await runEngine();

      positions.emit(mockAt(22.6780));
      await oneTick();
      expect(trips.trips['trip-1']!.mockLocationDetected, isTrue);

      positions.emit(fixAt(22.67817)); // driver stops mocking; real GPS again
      await oneTick();
      positions.emit(fixAt(22.6783));
      await oneTick();

      expect(trips.mockWrites, hasLength(1)); // no write of false, ever
      expect(trips.trips['trip-1']!.mockLocationDetected, isTrue);

      await engine.stop();
    });
  });

  group('offline queue (F-D7)', () {
    test('write failure → enqueue latest candidate; trail point still buffered',
        () async {
      final failingVans = _FailingVansRepository([van('van-01')]);
      final queue = _RecordingOfflineQueue();
      late final _FakeTrailBuffer buffer;
      final engine = TrackingEngine(
        vansRepository: failingVans,
        tripsRepository: trips,
        positionSource: positions,
        batterySource: battery,
        serviceHandle: service,
        trailBufferFactory: (tripId) async => buffer = _FakeTrailBuffer(),
        clock: () => clock,
        checkIntervalSec: 1,
        offlineWriteQueue: queue,
      );
      final started = await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );
      expect(started.isStarted, isTrue);

      positions.emit(fixAt(22.6780));
      await oneTick();

      expect(queue.enqueued, hasLength(1));
      expect(queue.enqueued.single, contains('van-01'));
      expect(buffer.pendingCount, 1); // finally-branch buffered the point
      expect(engine.state.status, TrackingRunStatus.running);

      await engine.stop(); // final flush lands the buffered point
      expect(trips.trips['trip-1']!.gpsTrail.length, 1);
    });
  });

  group('depot auto-end (ruling #29)', () {
    test('3 h parked inside 500 m → end-shift set, stop, one notice',
        () async {
      vans = FakeVansRepository([
        van(
          'van-01',
          status: VanStatus.onShift,
          tripId: 'trip-1',
          depot: (lat: 22.6780, lng: 77.0),
        ),
      ]);
      final notices = <String>[];
      final engine = buildEngine(onAutoEnd: notices.add);

      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );

      positions.emit(fixAt(22.6780)); // ~0 m from the depot
      await oneTick(); // dwell clock starts at 08:00

      clock = clock.add(const Duration(hours: 3));
      await oneTick();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final ended = trips.trips['trip-1']!;
      expect(ended.endedAt!.toUtc(), clock);
      expect(vans.vans['van-01']!.status, VanStatus.idle);
      expect(vans.vans['van-01']!.currentTripId, isNull);
      expect(service.stopCount, 1);
      expect(engine.state.status, TrackingRunStatus.idle);
      expect(notices, ['trip-1']);
    });

    test('no depot tag → a parked van never auto-ends', () async {
      vans = FakeVansRepository([
        van('van-01', status: VanStatus.onShift, tripId: 'trip-1'),
      ]);
      final engine = buildEngine();

      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );
      positions.emit(fixAt(22.6780));
      await oneTick();

      clock = clock.add(const Duration(hours: 6));
      await oneTick();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(trips.trips['trip-1']!.endedAt, isNull);
      expect(engine.state.status, TrackingRunStatus.running);

      await engine.stop();
    });

    test('a failed end write keeps the shift running and silent', () async {
      vans = FakeVansRepository([
        van(
          'van-01',
          status: VanStatus.onShift,
          tripId: 'trip-1',
          depot: (lat: 22.6780, lng: 77.0),
        ),
      ]);
      trips = _FailingEndTripsRepository([
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
      final notices = <String>[];
      final engine = buildEngine(onAutoEnd: notices.add);

      await engine.start(
        tripId: 'trip-1',
        vanId: 'van-01',
        notificationTitle: 'T',
        notificationBody: '',
      );
      positions.emit(fixAt(22.6780));
      await oneTick();

      clock = clock.add(const Duration(hours: 3));
      await oneTick();
      await Future<void>.delayed(const Duration(milliseconds: 300));

      expect(trips.trips['trip-1']!.endedAt, isNull);
      expect(vans.vans['van-01']!.status, VanStatus.onShift);
      expect(engine.state.status, TrackingRunStatus.running);
      expect(notices, isEmpty);

      await engine.stop();
    });
  });
}

/// Trips fake whose End Shift write always fails (offline / rules), so the
/// auto-end must keep the shift open instead of half-ending it.
class _FailingEndTripsRepository extends _RecordingTripsRepository {
  _FailingEndTripsRepository(super.seed);

  @override
  Future<void> setEndedAt(String tripId, DateTime endedAt) async {
    throw StateError('offline');
  }
}

// ---------------------------------------------------------------------------
// seam fakes
// ---------------------------------------------------------------------------

class _FakePositions implements PositionSource {
  final StreamController<VanFix> _controller =
      StreamController<VanFix>.broadcast();

  /// The filter the engine passed (null = not subscribed yet).
  int? distanceFilterM;

  void emit(VanFix fix) => _controller.add(fix);

  @override
  Stream<VanFix> fixes({required int distanceFilterM}) {
    this.distanceFilterM = distanceFilterM;
    return _controller.stream;
  }
}

class _FakeBattery implements BatterySource {
  _FakeBattery(this.value);

  int value;

  @override
  Future<int?> readBatteryPct() async => value;
}

class _FakeService implements ForegroundServiceHandle {
  bool _failNext = false;
  int startCount = 0;
  int stopCount = 0;

  void failNext() => _failNext = true;

  @override
  Future<ForegroundServiceStartResult> start({
    required String notificationTitle,
    required String notificationBody,
    required String vanId,
  }) async {
    startCount++;
    return _failNext
        ? ForegroundServiceStartResult.failed
        : ForegroundServiceStartResult.started;
  }

  @override
  Future<bool> stop() async {
    stopCount++;
    return true;
  }
}

class _FakeTrailBuffer implements TrailBuffer {
  final List<GpsPoint> _points = <GpsPoint>[];

  @override
  int get pendingCount => _points.length;

  @override
  Future<void> add(GpsPoint point) async => _points.add(point);

  @override
  Future<List<GpsPoint>> takeOldest({int? limit}) async {
    final count =
        limit == null || limit >= _points.length ? _points.length : limit;
    final take = _points.sublist(0, count);
    _points.removeRange(0, count);
    return take;
  }

  @override
  Future<void> putBackOldest(List<GpsPoint> points) async =>
      _points.insertAll(0, points);
}

/// Vans repository whose location writes always fail (dead-zone fake).
class _FailingVansRepository extends FakeVansRepository {
  _FailingVansRepository(super.seed);

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) async =>
      throw StateError('offline');
}

/// Records enqueue calls as compact strings; the real drain is ticket 12's.
class _RecordingOfflineQueue implements OfflineWriteQueue {
  final List<String> enqueued = <String>[];

  @override
  Future<void> enqueueLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    required DateTime recordedAt,
  }) async {
    enqueued.add('$vanId@$lat');
  }

  @override
  Future<QueuedLastLocation?> takeLastLocation() async => null;

  @override
  Future<void> putBackLastLocation(QueuedLastLocation item) async {}

  @override
  Future<int> get pendingLastLocationCount async => enqueued.length;
}
