/// Offline sync service tests (ticket 12, F-D7): the sync service against
/// seam fakes and REAL Hive boxes in a temp directory — no Firestore
/// (spec: seam 1 repositories via fakes; the acceptance criterion 4 to
/// test here is "2-minute network cut loses no GPS points").
///
/// Pattern follows tracking_engine_test.dart: real timers, NO fakeAsync
/// (it cannot pump chained async writes). A network dead zone is
/// simulated by throwing repository fakes + an offline connectivity fake;
/// "reconnect" by flipping the fakes and emitting the connectivity stream.
library;

import 'dart:async';
import 'dart:io';

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/core/repositories/repositories.dart';
import 'package:driverapp/features/tracking/data/hive_trail_buffer.dart';
import 'package:driverapp/features/tracking/domain/trail_buffer.dart';
import 'package:driverapp/features/tracking/offline/connectivity_source.dart';
import 'package:driverapp/features/tracking/offline/data/hive_firestore_timestamp_adapter.dart';
import 'package:driverapp/features/tracking/offline/offline_sync_service.dart';
import 'package:driverapp/features/tracking/offline/offline_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import '../repositories/fake_repositories.dart';

/// Shared fake clock (top-level so the seam fakes can record with it).
///
/// LOCAL on purpose: GpsPoint timestamps round-trip through
/// `firestore_time.dart`, which normalizes to LOCAL DateTime; a UTC clock
/// here would make `==` fail on isUtc after one round-trip.
final DateTime testBaseTime = DateTime(2026, 10, 24, 8);

void main() {
  // ---------------------------------------------------------------- fakes
  late FakeVansRepository fakeVans;
  late FakeTripsRepository fakeTrips;
  late _FaultyVans vans; // wrapping fake: throws while "offline"
  late _FaultyTrips trips;
  late _FakeConnectivity connectivity;
  late HiveOfflineWriteQueue queue;
  late Directory tempDir;

  final baseTime = testBaseTime;

  Van van(String id, {VanStatus status = VanStatus.idle, String? tripId}) =>
      Van(
        id: id,
        plateNo: 'MH-01',
        routeId: 'route-01',
        status: status,
        lastLocation: null,
        currentTripId: tripId,
        batteryPct: null,
      );

  /// Trip seed (the engine — ticket 05 — never creates trips).
  Trip trip(String id) => Trip(
    id: id,
    vanId: 'van-01',
    routeId: 'route-01',
    driverId: '',
    wardIds: const <String>[],
    date: DateTime.utc(2026, 10, 24),
    startedAt: baseTime,
    endedAt: null,
    wardsDone: const <WardDone>[],
    alertedWardIds: const <String>[],
    gpsTrail: const <GpsPoint>[],
    mockLocationDetected: false,
  );

  /// One trail point, strictly increasing time, in 0.2 shape {lat,lng,t}.
  GpsPoint point(int index) => GpsPoint(
    lat: 22.60000 + index / 100000,
    lng: 77.0,
    t: baseTime.add(Duration(seconds: 30 * index)),
  );

  /// Lets in-flight async work settle without fakeAsync.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  OfflineSyncService buildService({int? catchUpBatchPoints}) =>
      OfflineSyncService(
        vansRepository: vans,
        tripsRepository: trips,
        writeQueue: queue,
        connectivitySource: connectivity,
        trailBufferFactory: preparedTrailBuffer,
        catchUpBatchPoints: catchUpBatchPoints,
      );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('offline-sync-test');
    Hive.init(tempDir.path);
    // The durable Trail buffer persists `GpsPoint.toMap()` records whose
    // `t` is a Firestore Timestamp — register the adapter BEFORE any box
    // opens (in production the bootstrap does this exactly once).
    if (!Hive.isAdapterRegistered(207)) {
      Hive.registerAdapter(FirestoreTimestampAdapter());
    }
    fakeVans = FakeVansRepository([van('van-01', tripId: 'trip-1')]);
    fakeTrips = FakeTripsRepository([trip('trip-1')]);
    vans = _FaultyVans(fakeVans);
    trips = _FaultyTrips(fakeTrips);
    connectivity = _FakeConnectivity();
    queue = HiveOfflineWriteQueue();
  });

  tearDown(() async {
    try {
      await Hive.close();
    } catch (_) {
      // Close races on a crashed test must not mask the real failure.
    }
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('network cut mid-shift → zero lost, all land in order', () {
    test(
      'trail points queued while offline all land in order on reconnect',
      () async {
        final sync = buildService();
        sync.start();
        sync.attachTrip('trip-1');
        connectivity.current = false; // dead zone

        // The engine keeps buffering accepted points while offline; the
        // flush passes fail and append nothing.
        final buffer = await preparedTrailBuffer('trip-1');
        for (var index = 1; index <= 7; index++) {
          await buffer.add(point(index));
        }
        trips.failAppends = true; // Firestore unreachable (throwing fake)

        await sync.flushNow();
        await settle();

        expect(fakeTrips.trips['trip-1']!.gpsTrail, isEmpty); // nothing landed
        // Zero lost: every point is still durably pending in the buffer.
        expect(buffer.pendingCount, 7);

        // Reconnect: the flush fires and ALL points land, in order.
        trips.failAppends = false;
        connectivity.emit(true);
        await settle();

        final trail = fakeTrips.trips['trip-1']!.gpsTrail;
        expect(trail.length, 7);
        for (var index = 1; index <= 7; index++) {
          expect(trail[index - 1], point(index)); // original order, no dupes
        }
        expect(buffer.pendingCount, 0);
      },
    );

    test(
      'failed batches go back to the QUEUE FRONT, order preserved',
      () async {
        final sync = buildService(catchUpBatchPoints: 3);
        sync.start();
        sync.attachTrip('trip-1');
        final buffer = await preparedTrailBuffer('trip-1');
        for (var index = 1; index <= 7; index++) {
          await buffer.add(point(index));
        }

        // Appends: #1 lands (points 1..3), #2 FAILS mid-drain (points
        // 4..6), #3 never runs while a batch is failing — the failed
        // batch goes back to the FRONT, order preserved.
        trips.useAppendScript([false, true, false]);
        await sync.flushNow();
        await settle();

        final landed = fakeTrips.trips['trip-1']!.gpsTrail;
        expect(landed.length, 3);
        expect(landed.first.lat, point(1).lat);
        final waiting = _rawPending('trip-1');
        expect(waiting.length, 4);
        expect(waiting.first.lat, point(4).lat); // FRONT restore
        expect(waiting.last.lat, point(7).lat); // in order

        trips.appendScript = null; // network fine again
        await sync.flushNow(); // all remaining, in the same order
        await settle();

        final total = fakeTrips.trips['trip-1']!.gpsTrail;
        expect(total.length, 7);
        for (var index = 1; index <= 7; index++) {
          expect(total[index - 1], point(index));
        }
        expect(buffer.pendingCount, 0);
      },
    );
  });

  group('stale-vs-latest lastLocation rule (0.13 note)', () {
    test('only the LATEST candidate is ever written to the van doc', () async {
      final sync = buildService();
      sync.start();
      connectivity.current = false;
      vans.failLastLocation = true; // offline

      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6780,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: baseTime,
      );
      await sync.flushNow(); // send fails; the candidate must survive
      await settle();
      expect(vans.lastLocationWrites, hasLength(1)); // attempted…
      expect(fakeVans.vans['van-01']!.lastLocation, isNull); // …but failed
      expect(await queue.pendingLastLocationCount, 1); // still queued

      // A newer fix is accepted while still offline: the queue REPLACES
      // the older candidate (only the latest matters for the live map).
      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6790,
        lng: 77.1,
        speedKmph: 14,
        recordedAt: baseTime.add(const Duration(minutes: 5)),
      );

      // The FAILED older candidate must never resurface after or before
      // the newer one: it was dropped (putBack rule, see
      // offline_write_queue_test) and here only the latest remains.
      vans.failLastLocation = false;
      connectivity.emit(true); // reconnect flush
      await settle();

      final writes = vans.lastLocationWrites;
      expect(writes, hasLength(2)); // 1 failed attempt + 1 landed
      expect(writes.last.lat, 22.6790); // never the stale 22.6780
      expect(fakeVans.vans['van-01']!.lastLocation!.lat, 22.6790);
      expect(await queue.pendingLastLocationCount, 0);
    });

    test('a landed flush is never repeated', () async {
      final sync = buildService();
      sync.start();
      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6780,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: baseTime,
      );
      connectivity.emit(true); // initial online → flush
      await settle();
      expect(fakeVans.vans['van-01']!.lastLocation!.lat, 22.6780);
      expect(vans.lastLocationWrites, hasLength(1));

      connectivity.emit(true); // still online: nothing left to send
      await settle();

      expect(vans.lastLocationWrites, hasLength(1));
      expect(await queue.pendingLastLocationCount, 0);
    });
  });

  group('catch-up batch shape (PRD-2 0.13 Flow A step 4)', () {
    test(
      'backlog drains as ordered single appends, ≤ the batch cap each',
      () async {
        final sync = buildService(catchUpBatchPoints: 3);
        sync.start();
        sync.attachTrip('trip-1');
        final buffer = await preparedTrailBuffer('trip-1');
        for (var index = 1; index <= 7; index++) {
          await buffer.add(point(index));
        }

        await sync.flushNow();
        await settle();

        // Each catch-up append = ONE ordered appendGpsTrail write through
        // the SAME repository pattern the engine flush uses; chunked at 3.
        expect(trips.trailAppends.map((batch) => batch.length), [3, 3, 1]);
        expect(trips.trailAppends.expand((batch) => batch).toList(), [
          point(1),
          point(2),
          point(3),
          point(4),
          point(5),
          point(6),
          point(7),
        ]);
        // And the doc state holds the whole trail in order.
        expect(fakeTrips.trips['trip-1']!.gpsTrail.length, 7);
      },
    );
  });

  group('un-synced count (subtle surface)', () {
    test('count stream decrements to 0 as flushes succeed', () async {
      final sync = buildService(catchUpBatchPoints: 2);
      sync.start();

      vans.failLastLocation = true; // lastLocation waits
      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6780,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: baseTime,
      );
      sync.attachTrip('trip-1');
      final buffer = await preparedTrailBuffer('trip-1');
      for (var index = 1; index <= 4; index++) {
        await buffer.add(point(index));
      }
      trips.failAppends = true;
      await settle();

      final counts = <int>[];
      final sub = sync.pendingCountStream.listen(counts.add);
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(counts, [5]); // 1 lastLocation + 4 trail points

      // Reconnect: lastLocation first, then 2 point batches; the count
      // ticks down towards 0 each successful flush.
      vans.failLastLocation = false;
      trips.failAppends = false;
      await sync.flushNow();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(counts, [5, 4, 2, 0]); // strictly decreasing
      await sub.cancel();
    });

    test(
      'offline failures do not drop the count (nothing silently lost)',
      () async {
        final sync = buildService();
        sync.start();
        sync.attachTrip('trip-1');
        final buffer = await preparedTrailBuffer('trip-1');
        await buffer.add(point(1));

        trips.failAppends = true;
        await sync.flushNow();
        await settle();

        expect(await sync.currentPendingCount(), 1);
        trips.failAppends = false;
        await sync.flushNow();
        await settle();
        expect(await sync.currentPendingCount(), 0);
      },
    );
  });

  group('durability across a simulated app restart', () {
    test(
      'reopen the service over the SAME Hive dir → everything lands',
      () async {
        var sync = buildService(catchUpBatchPoints: 2);
        sync.start();
        sync.attachTrip('trip-1');
        connectivity.current = false;

        vans.failLastLocation = true;
        await queue.enqueueLastLocation(
          vanId: 'van-01',
          lat: 22.6800,
          lng: 77.2,
          speedKmph: 9,
          recordedAt: baseTime,
        );
        final buffer = await preparedTrailBuffer('trip-1');
        for (var index = 1; index <= 5; index++) {
          await buffer.add(point(index));
        }
        trips.failAppends = true;
        await sync.flushNow(); // offline pass: everything fails, nothing lost
        await settle();

        // "App kill": close every Hive box, drop the old service objects.
        await Hive.close();

        // "Restart": re-init Hive over the SAME temp dir, fresh service.
        Hive.init(tempDir.path);
        vans = _FaultyVans(fakeVans); // fresh wrappers, "network is back"
        trips = _FaultyTrips(fakeTrips);
        queue = HiveOfflineWriteQueue();
        connectivity = _FakeConnectivity(current: true);
        final restarted = buildService(catchUpBatchPoints: 2);
        // Attach BEFORE starting so the initial online event flushes the
        // whole backlog in one pass.
        restarted.attachTrip('trip-1');
        restarted.start();
        sync = restarted;

        await Future<void>.delayed(const Duration(milliseconds: 60));
        await sync.flushNow(); // merger with the listener-triggered pass
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // lastLocation: exactly the queued latest one, once.
        expect(fakeVans.vans['van-01']!.lastLocation!.lat, 22.6800);
        expect(vans.lastLocationWrites, hasLength(1));
        // Trail: all 5 points, in order, restored count → 0.
        expect(fakeTrips.trips['trip-1']!.gpsTrail.length, 5);
        for (var index = 1; index <= 5; index++) {
          expect(fakeTrips.trips['trip-1']!.gpsTrail[index - 1], point(index));
        }
        expect(await sync.currentPendingCount(), 0);
      },
    );
  });
}

/// Reads the raw pending trail of a trip straight from its Hive box
/// (assertion of ORDER of undrained points without touching them).
List<GpsPoint> _rawPending(String tripId) {
  final box = Hive.box(trailBoxName(tripId));
  final raw = box.get(trailBoxEntryKey);
  if (raw is! List) return const <GpsPoint>[];
  return raw
      .whereType<Map>()
      .map(
        (map) => GpsPoint.fromMap(
          Map<String, Object?>.from(map as Map<Object?, Object?>),
        ),
      )
      .toList();
}

/// Trail buffer factory for THIS suite: identical to the engine's
/// HiveTrailBuffer.open apart from one priming pass — see REPORT gap:
/// `HiveTrailBuffer.add`/`putBackOldest` crash on a box that was never
/// written yet (`const []` is unmodifiable, data/hive_trail_buffer.dart
/// `_read`). The tests must not depend on that pre-existing bug; the
/// factory primes ONLY an empty box (never after it holds points).
Future<TrailBuffer> preparedTrailBuffer(String tripId) async {
  final box = await Hive.openBox(trailBoxName(tripId));
  if (box.get(trailBoxEntryKey) == null) {
    await box.put(trailBoxEntryKey, <Map<String, Object?>>[]);
  }
  return HiveTrailBuffer(box);
}

// ---------------------------------------------------------------------------
// seam fakes (local to this suite; the shared fakes stay untouched)
// ---------------------------------------------------------------------------

class _FakeConnectivity implements ConnectivitySource {
  _FakeConnectivity({this.current = false});

  bool current;

  final _events = StreamController<bool>.broadcast();

  void emit(bool online) {
    current = online;
    _events.add(online);
  }

  @override
  Stream<bool> get status => Stream<bool>.multi((controller) {
    final subscription = _events.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = () => subscription.cancel();
    // The source contract: current state first.
    controller.add(current);
  });
}

/// A [VansRepository] that throws while the "network" is down
/// (`failLastLocation`), recording every attempted lastLocation write —
/// the fake mirrors what Firestore would do in a dead zone (engaged by
/// noise/timeouts rather than semantics).
class _FaultyVans implements VansRepository {
  _FaultyVans(this._inner);

  final FakeVansRepository _inner;

  bool failLastLocation = false;

  /// Every updateLastLocation ATTEMPT, in call order.
  final List<QueuedLastLocation> lastLocationWrites = [];

  @override
  Future<List<Van>> readVans() => _inner.readVans();

  @override
  Stream<Van?> watchVan(String vanId) => _inner.watchVan(vanId);

  @override
  Future<void> updateLastLocation({
    required String vanId,
    required double lat,
    required double lng,
    required double speedKmph,
    DateTime? updatedAt,
  }) async {
    lastLocationWrites.add(
      QueuedLastLocation(
        vanId: vanId,
        lat: lat,
        lng: lng,
        speedKmph: speedKmph,
        recordedAt: testBaseTime,
      ),
    );
    if (failLastLocation) throw StateError('offline (fake network dead)');
    await _inner.updateLastLocation(
      vanId: vanId,
      lat: lat,
      lng: lng,
      speedKmph: speedKmph,
      updatedAt: updatedAt,
    );
  }

  @override
  Future<void> updateStatus(String vanId, VanStatus status) =>
      _inner.updateStatus(vanId, status);

  @override
  Future<void> updateBatteryPct(String vanId, int batteryPct) =>
      _inner.updateBatteryPct(vanId, batteryPct);

  @override
  Future<Van?> readVan(String vanId) => _inner.readVan(vanId);

  @override
  Future<void> updateCurrentTripId(String vanId, String? tripId) =>
      _inner.updateCurrentTripId(vanId, tripId);
}

class _FaultyTrips implements TripsRepository {
  _FaultyTrips(this._inner);

  final FakeTripsRepository _inner;

  /// When true, EVERY append throws (a stretch of dead network).
  bool failAppends = false;

  /// Exactly the next [n] appends throw (a transient failure pattern).
  int failNextAppends = 0;

  /// Per-append script `true` = THAT append call throws; `null` falls
  /// back to [failAppends]/[failNextAppends]. Set via [useAppendScript].
  List<bool>? appendScript;

  int _scriptIndex = 0;

  void useAppendScript(List<bool> script) {
    appendScript = script;
    _scriptIndex = 0;
  }

  /// Every SUCCESSFUL append, one entry per appendGpsTrail call.
  final List<List<GpsPoint>> trailAppends = [];

  @override
  Future<Trip> createTrip(Trip trip) => _inner.createTrip(trip);

  @override
  Future<void> appendWardDone(String tripId, WardDone entry) =>
      _inner.appendWardDone(tripId, entry);

  @override
  Future<void> appendGpsTrail(String tripId, List<GpsPoint> points) async {
    final bool failing;
    if (appendScript != null) {
      failing =
          _scriptIndex < appendScript!.length && appendScript![_scriptIndex];
      _scriptIndex++;
    } else {
      failing = failAppends || failNextAppends > 0;
      if (failNextAppends > 0) failNextAppends--;
    }
    if (failing) {
      throw StateError('offline (fake network dead)');
    }
    await _inner.appendGpsTrail(tripId, points);
    trailAppends.add(List.of(points));
  }

  @override
  Future<void> setEndedAt(String tripId, DateTime endedAt) =>
      _inner.setEndedAt(tripId, endedAt);

  @override
  Future<void> setMockLocationDetected(
    String tripId, {
    required bool detected,
  }) => _inner.setMockLocationDetected(tripId, detected: detected);

  @override
  Stream<Trip?> watchTripByVanIdAndDate({
    required String vanId,
    required DateTime date,
  }) => _inner.watchTripByVanIdAndDate(vanId: vanId, date: date);

  @override
  Future<Trip?> readTrip(String tripId) => _inner.readTrip(tripId);

  @override
  Stream<List<Trip>> watchRecentTrips({
    required String vanId,
    required DateTime asOfDate,
    int limit = 30,
  }) => _inner.watchRecentTrips(
        vanId: vanId,
        asOfDate: asOfDate,
        limit: limit,
      );
}
