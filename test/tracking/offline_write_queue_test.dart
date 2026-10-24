/// Offline write queue tests (ticket 12): the durable Hive queue against a
/// temp-dir Hive init — no Firebase, no platform channels.
///
/// Covers the "latest only" rule (0.13 note: the queue never re-queues an
/// older `vans.lastLocation` after a newer one), take/put-back discipline
/// for failed sends, and durability across a simulated app restart.
library;

import 'dart:io';

import 'package:driverapp/features/tracking/offline/offline_write_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late HiveOfflineWriteQueue queue;

  QueuedLastLocation candidate(double lat, {required DateTime t}) =>
      QueuedLastLocation(
        vanId: 'van-01',
        lat: lat,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: t,
      );

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('offline-queue-test');
    Hive.init(tempDir.path);
    queue = HiveOfflineWriteQueue();
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  group('latest only (0.13 note)', () {
    test(
      'enqueueing a newer candidate REPLACES the queued older one',
      () async {
        final t1 = DateTime.utc(2026, 10, 24, 8);
        final t2 = DateTime.utc(2026, 10, 24, 8, 0, 10);

        await queue.enqueueLastLocation(
          vanId: 'van-01',
          lat: 22.6780,
          lng: 77.0,
          speedKmph: 12,
          recordedAt: t1,
        );
        await queue.enqueueLastLocation(
          vanId: 'van-01',
          lat: 22.6790,
          lng: 77.1,
          speedKmph: 14,
          recordedAt: t2,
        );

        expect(await queue.pendingLastLocationCount, 1); // single slot
        final queued = await queue.takeLastLocation();
        expect(queued!.lat, 22.6790); // the latest
        expect(queued.recordedAt, t2);
      },
    );

    test(
      'putBack of a stale candidate is DROPPED when a newer one is queued',
      () async {
        final t1 = DateTime.utc(2026, 10, 24, 8);
        final t2 = DateTime.utc(2026, 10, 24, 8, 0, 10);
        final failedOld = candidate(22.6780, t: t1);

        // The send of FAILED, and meanwhile a newer candidate was enqueued.
        await queue.enqueueLastLocation(
          vanId: 'van-01',
          lat: 22.6790,
          lng: 77.1,
          speedKmph: 14,
          recordedAt: t2,
        );
        await queue.putBackLastLocation(failedOld);

        expect(await queue.pendingLastLocationCount, 1);
        final queued = await queue.takeLastLocation();
        expect(queued!.lat, 22.6790); // stale one never resurfaces
      },
    );

    test('putBack of a newer candidate replaces an older queued one', () async {
      final t1 = DateTime.utc(2026, 10, 24, 8);
      final t2 = DateTime.utc(2026, 10, 24, 8, 0, 10);
      final failedNew = candidate(22.6790, t: t2);

      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6780,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: t1,
      );
      // Newer send failed AFTER the older was queued: the newer one must
      // win (never send the older over it).
      await queue.putBackLastLocation(failedNew);

      final queued = await queue.takeLastLocation();
      expect(queued!.lat, 22.6790);
    });

    test('putBack into an EMPTY queue keeps the item (zero lost)', () async {
      final failed = candidate(22.6780, t: DateTime.utc(2026, 10, 24, 8));
      await queue.putBackLastLocation(failed);
      expect(await queue.pendingLastLocationCount, 1);
      expect((await queue.takeLastLocation())!.lat, 22.6780);
    });
  });

  group('take / count', () {
    test('take empties the slot', () async {
      final t = DateTime.utc(2026, 10, 24, 8);
      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6780,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: t,
      );
      expect(await queue.pendingLastLocationCount, 1);

      final item = await queue.takeLastLocation();
      expect(item!.lat, 22.6780);

      expect(await queue.pendingLastLocationCount, 0);
      expect(await queue.takeLastLocation(), isNull);
    });

    test('empty queue → count 0', () async {
      expect(await queue.pendingLastLocationCount, 0);
    });
  });

  group('durability (app kill/restart while offline)', () {
    test('pending candidate survives a full Hive restart', () async {
      final t = DateTime.utc(2026, 10, 24, 8, 0, 42);
      await queue.enqueueLastLocation(
        vanId: 'van-01',
        lat: 22.6780,
        lng: 77.0,
        speedKmph: 12,
        recordedAt: t,
      );

      // Simulate the app process being killed: the box is closed.
      await Hive.close();

      // "Restart": Hive re-init over the SAME directory, NEW queue object.
      Hive.init(tempDir.path);
      final reopened = HiveOfflineWriteQueue();

      expect(await reopened.pendingLastLocationCount, 1);
      final item = await reopened.takeLastLocation();
      expect(item!.vanId, 'van-01');
      expect(item.lat, 22.6780);
      expect(item.recordedAt, t);
    });
  });
}
