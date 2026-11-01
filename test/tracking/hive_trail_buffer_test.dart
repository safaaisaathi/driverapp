/// Hive-backed Trail buffer: the declared cap is real (issue #13) and the
/// order guarantees hold around it. Temp-dir Hive only — no Firebase.
library;

import 'dart:io';

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/tracking/data/hive_trail_buffer.dart';
import 'package:driverapp/features/tracking/domain/trail_buffer.dart';
import 'package:driverapp/features/tracking/offline/data/hive_firestore_timestamp_adapter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('trail-buffer-test');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(207)) {
      Hive.registerAdapter(FirestoreTimestampAdapter());
    }
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  GpsPoint point(int i) =>
      GpsPoint(lat: i.toDouble(), lng: 77, t: DateTime.utc(2026, 10, 24, 8));

  test('the buffer cap drops the OLDEST point when full (issue #13)', () async {
    final box = await Hive.openBox('trail-cap');
    final seeded = [
      for (var i = 0; i < maxTrailBufferPoints; i++) point(i).toMap(),
    ];
    await box.put(trailBoxEntryKey, seeded);
    final buffer = HiveTrailBuffer(box);
    expect(buffer.pendingCount, maxTrailBufferPoints);

    await buffer.add(point(999999));
    expect(buffer.pendingCount, maxTrailBufferPoints);

    final remaining = await buffer.takeOldest();
    expect(remaining.first.lat, 1, reason: 'the oldest (0) was dropped');
    expect(remaining.last.lat, 999999);
  });

  test('takeOldest honours a limit and keeps the rest in order', () async {
    final box = await Hive.openBox('trail-limit');
    await box.put(trailBoxEntryKey, [
      for (var i = 0; i < 5; i++) point(i).toMap(),
    ]);
    final buffer = HiveTrailBuffer(box);

    final batch = await buffer.takeOldest(limit: 2);
    expect(batch.map((p) => p.lat), [0, 1]);
    expect(buffer.pendingCount, 3);

    final rest = await buffer.takeOldest();
    expect(rest.map((p) => p.lat), [2, 3, 4]);
  });

  test('putBackOldest re-inserts a failed batch at the FRONT', () async {
    final box = await Hive.openBox('trail-putback');
    final buffer = HiveTrailBuffer(box);
    await buffer.add(point(2));
    await buffer.add(point(3));

    await buffer.putBackOldest([point(0), point(1)]);
    final all = await buffer.takeOldest();
    expect(all.map((p) => p.lat), [0, 1, 2, 3]);
  });
}
