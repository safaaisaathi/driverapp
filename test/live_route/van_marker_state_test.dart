/// Van-marker stale-decision tests (ticket 06, contract 0.13/0.4):
/// a fix older than `staleLocationSec` renders stale (grey marker +
/// "last seen X min ago" caption, floored minutes — ruling 6).
library;

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/live_route/domain/van_marker_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 24, 9, 30);

  VanLastLocation location({DateTime? updatedAt, double speed = 10}) =>
      VanLastLocation(
        lat: 22.77,
        lng: 73.71,
        speedKmph: speed,
        updatedAt: updatedAt,
      );

  group('stale decision', () {
    test('fresh within staleLocationSec (59 s) → not stale', () {
      final state =
          VanMarkerState.of(location(updatedAt: now), now.add(const Duration(seconds: 59)));
      expect(state.isStale, isFalse);
    });

    test('exactly staleLocationSec (60 s) is NOT older → not stale', () {
      // "older than STALE_LOCATION_SEC": the boundary itself is not older.
      final state =
          VanMarkerState.of(location(updatedAt: now), now.add(const Duration(seconds: 60)));
      expect(state.isStale, isFalse);
    });

    test('61 s → stale', () {
      final state =
          VanMarkerState.of(location(updatedAt: now), now.add(const Duration(seconds: 61)));
      expect(state.isStale, isTrue);
    });

    test('null updatedAt (unknown age) counts stale', () {
      final state = VanMarkerState.of(location(updatedAt: null), now);
      expect(state.isStale, isTrue);
    });

    test('null location (no fix yet) counts stale, minutes 0', () {
      final state = VanMarkerState.of(null, now);
      expect(state.isStale, isTrue);
      expect(state.minutesSinceUpdate, 0);
    });

    test('clock skew (updatedAt after now) clamps minutes to 0', () {
      final state =
          VanMarkerState.of(location(updatedAt: now.add(const Duration(minutes: 3))), now);
      expect(state.isStale, isFalse);
      expect(state.minutesSinceUpdate, 0);
    });
  });

  group('minutes caption', () {
    test('floors minutes (ruling 6): 119 s → 1 min', () {
      final state = VanMarkerState.of(
        location(updatedAt: now),
        now.add(const Duration(seconds: 119)),
      );
      expect(state.isStale, isTrue);
      expect(state.minutesSinceUpdate, 1);
    });

    test('larger gaps floor too: 61 min → 61', () {
      final state = VanMarkerState.of(
        location(updatedAt: now),
        now.add(const Duration(minutes: 61)),
      );
      expect(state.minutesSinceUpdate, 61);
    });
  });

  test('carries position and speed through', () {
    final state = VanMarkerState.of(
      location(updatedAt: now, speed: 12.5),
      now,
    );
    expect(state.position.lat, 22.77);
    expect(state.position.lng, 73.71);
    expect(state.speedKmph, 12.5);
  });
}
