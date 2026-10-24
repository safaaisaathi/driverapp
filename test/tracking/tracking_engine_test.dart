/// Tracking engine tests (ticket 05): engine against seam fakes only — no
/// platform channels, no Firestore (spec Testing Decisions: seam 1 =
/// repositories via fake_repositories; the real Write Policy code runs).
///
/// Covers F-D2 + F-D8 acceptances that don't need a device: policy-driven
/// writes, trail buffering/batching order, resume reattach, stop-flush,
/// service-failure states, and the Flow F revive (offline → on_shift on
/// next write). Real-device behaviour (permissions, service survival) is
/// ticket 14.
///
/// Timer tests run on REAL timers with the test-only cadence overrides
/// (`checkIntervalSec: 1`) instead of fakeAsync: fakeAsync cannot pump the
/// async/await resumptions the engine's write chains use (learned the hard
/// way), and real 1-second ticks are simple and sufficient.
library;

import 'dart:async';

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/tracking/domain/battery_source.dart';
import 'package:driverapp/features/tracking/domain/foreground_service.dart';
import 'package:driverapp/features/tracking/domain/position_fix.dart';
import 'package:driverapp/features/tracking/domain/position_source.dart';
import 'package:driverapp/features/tracking/domain/tracking_engine.dart';
import 'package:driverapp/features/tracking/domain/trail_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

import '../repositories/fake_repositories.dart';

void main() {
  // ---------------------------------------------------------------- fakes
  late FakeVansRepository vans;
  late FakeTripsRepository trips;
  late _FakePositions positions;
  late _FakeBattery battery;
  late _FakeService service;
  var clock = DateTime.utc(2026, 10, 24, 8); // fixed fake clock

  Van van(
    String id, {
    VanStatus status = VanStatus.idle,
    String? tripId,
  }) =>
      Van(
        id: id,
        plateNo: 'MH-01',
        routeId: 'route-01',
        status: status,
        lastLocation: null,
        currentTripId: tripId,
        batteryPct: null,
      );

  VanFix fixAt(double lat, {double lng = 77.0}) =>
      VanFix(lat: lat, lng: lng, speedKmph: 12, t: clock);

  /// One full cadence with margin (check interval overridden to 1 s).
  Future<void> oneTick() => Future<void>.delayed(
        const Duration(milliseconds: 1400),
      );

  TrackingEngine buildEngine({int check = 1, int? flush}) => TrackingEngine(
        vansRepository: vans,
        tripsRepository: trips,
        positionSource: positions,
        batterySource: battery,
        serviceHandle: service,
        trailBufferFactory: (tripId) async => _FakeTrailBuffer(),
        clock: () => clock,
        checkIntervalSec: check,
        flushIntervalSec: flush,
      );

  setUp(() {
    vans = FakeVansRepository([van('van-01')]);
    trips = FakeTripsRepository([
      // The engine never creates trips — the trip doc exists before the
      // engine starts (Start Shift / D1 creates it; ticket 04).
      Trip(
        id: 'trip-1',
        vanId: 'van-01',
        routeId: 'route-01',
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
      await Future<void>.delayed(const Duration(milliseconds: 900));
      // flush tick fired around t=3 s: A and B appended, in order.

      final trail = trips.trips['trip-1']!.gpsTrail;
      expect(trail.length, 2);
      expect(trail.first.lat, 22.6780);
      expect(trail.last.lat, closeTo(22.67817, 1e-9));

      await engine.stop();
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
  Future<bool> stop() async => true;
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
