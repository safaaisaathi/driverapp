import 'package:driverapp/core/config/constants.dart';
import 'package:driverapp/core/domain/geo.dart';
import 'package:driverapp/core/domain/geo_point.dart';
import 'package:driverapp/core/domain/write_policy.dart';
import 'package:flutter_test/flutter_test.dart';

// Degrees of latitude per metre on the spherical Earth used by haversine —
// pure-constant based helper so tests stay tz- and device-free.
final double degLatPerMetre = 1 / 111194.92664455873;

GeoPoint northOf(GeoPoint base, double metres) =>
    (lat: base.lat + metres * degLatPerMetre, lng: base.lng);

GeoPoint point(double lat, double lng) => (lat: lat, lng: lng);

void main() {
  final base = point(22.7775, 73.6177); // Godhra

  DateTime at(DateTime start, int secondsLater) =>
      start.add(Duration(seconds: secondsLater));

  group('decideWrite — fresh start', () {
    test('null lastWritten always writes, regardless of time or battery', () {
      final now = DateTime.utc(2026, 1, 15, 10, 0, 0);
      final batteryLow = decideWrite(
        candidate: base,
        lastWritten: null,
        lastWriteTime: DateTime.utc(2026, 1, 15, 9, 0, 0),
        batteryPct: 5,
        now: now,
      );
      final noTime = decideWrite(
        candidate: base,
        lastWritten: null,
        lastWriteTime: null,
        batteryPct: null,
        now: now,
      );

      expect(batteryLow.shouldWrite, isTrue);
      expect(batteryLow.reason, WriteReason.firstWrite);
      expect(noTime.shouldWrite, isTrue);
      expect(noTime.reason, WriteReason.firstWrite);
    });

    test('fresh start with null battery and null lastWriteTime', () {
      final d = decideWrite(
        candidate: base,
        lastWritten: null,
        lastWriteTime: null,
        batteryPct: null,
        now: DateTime.utc(2026, 1, 15),
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, WriteReason.firstWrite);
      expect(d.intervalUsed, gpsIntervalSec);
    });
  });

  group('decideWrite — movement rule', () {
    final now = DateTime.utc(2026, 1, 15, 10, 0, 0);
    final lastWrite = now.subtract(const Duration(seconds: 5));
    final lastWritten = base;

    test('moved < minMoveM within heartbeat → skip', () {
      // ~5.56 m from the last written point.
      final candidate = northOf(base, 5.5);
      final d = decideWrite(
        candidate: candidate,
        lastWritten: lastWritten,
        lastWriteTime: lastWrite,
        batteryPct: 80,
        now: now,
      );
      expect(d.shouldWrite, isFalse);
      expect(d.reason, WriteReason.skipped);
    });

    test('moved ≥ minMoveM → write even within heartbeat', () {
      // ~33.4 m from the last written point (well over minMoveM).
      final candidate = northOf(base, minMoveM * 2 + 3);
      final d = decideWrite(
        candidate: candidate,
        lastWritten: lastWritten,
        lastWriteTime: lastWrite,
        batteryPct: 80,
        now: now,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, WriteReason.moved);
    });

    test('moved just past minMoveM → write (≥ is inclusive)', () {
      final candidate = northOf(base, minMoveM + 0.01);
      final d = decideWrite(
        candidate: candidate,
        lastWritten: lastWritten,
        lastWriteTime: lastWrite,
        batteryPct: 80,
        now: now,
      );
      // The candidate sits ~1 cm past the threshold — the haversine result
      // must land at minMoveM within a metre, so the move rule fires.
      expect(haversineDistanceM(candidate, lastWritten),
          closeTo(minMoveM + 0.01, 0.05));
      expect(d.shouldWrite, isTrue);
      expect(d.reason, WriteReason.moved);
    });

    test('stationary past heartbeat → write (stopped van never looks dead)',
        () {
      final d = decideWrite(
        candidate: base, // identical to last written point
        lastWritten: lastWritten,
        lastWriteTime: at(now, -heartbeatSec), // exactly heartbeatSec ago
        batteryPct: 80,
        now: now,
      );
      expect(d.shouldWrite, isTrue);
      expect(d.reason, WriteReason.heartbeat);
    });

    test('stationary one second before heartbeat → skip', () {
      final d = decideWrite(
        candidate: base,
        lastWritten: lastWritten,
        lastWriteTime: at(now, -(heartbeatSec - 1)),
        batteryPct: 80,
        now: now,
      );
      expect(d.shouldWrite, isFalse);
      expect(d.reason, WriteReason.skipped);
    });

    test('lastWritten set but lastWriteTime null: movement decides only', () {
      final unmoved = decideWrite(
        candidate: base,
        lastWritten: lastWritten,
        lastWriteTime: null,
        batteryPct: 80,
        now: now,
      );
      expect(unmoved.shouldWrite, isFalse);

      final moved = decideWrite(
        candidate: northOf(base, minMoveM + 1),
        lastWritten: lastWritten,
        lastWriteTime: null,
        batteryPct: 80,
        now: now,
      );
      expect(moved.shouldWrite, isTrue);
      expect(moved.reason, WriteReason.moved);
    });
  });

  group('decideWrite — battery switches the interval', () {
    test('battery just below lowBatteryPct uses gpsIntervalLowBatterySec', () {
      final d = decideWrite(
        candidate: base,
        lastWritten: null,
        lastWriteTime: null,
        batteryPct: lowBatteryPct - 1,
        now: DateTime.utc(2026, 1, 15),
      );
      expect(d.intervalUsed, gpsIntervalLowBatterySec);
    });

    test('battery exactly lowBatteryPct is NOT low (below, not at)', () {
      final d = decideWrite(
        candidate: base,
        lastWritten: null,
        lastWriteTime: null,
        batteryPct: lowBatteryPct,
        now: DateTime.utc(2026, 1, 15),
      );
      expect(d.intervalUsed, gpsIntervalSec);
    });

    test('null battery treated healthy', () {
      final d = decideWrite(
        candidate: base,
        lastWritten: null,
        lastWriteTime: null,
        batteryPct: null,
        now: DateTime.utc(2026, 1, 15),
      );
      expect(d.intervalUsed, gpsIntervalSec);
    });

    test('healthy battery uses gpsIntervalSec', () {
      final d = decideWrite(
        candidate: base,
        lastWritten: null,
        lastWriteTime: null,
        batteryPct: 100,
        now: DateTime.utc(2026, 1, 15),
      );
      expect(d.intervalUsed, gpsIntervalSec);
    });
  });
}
