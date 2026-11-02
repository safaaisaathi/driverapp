/// Depot dwell rule tests (PRD-2 §0.16 ruling #29).
///
/// Pure domain: no timers, no Firestore. The engine wires this tracker into
/// its cadence; the engine test covers the auto-end writes.
library;

import 'package:driverapp/features/tracking/domain/depot_dwell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ~111 m per 0.001 degree of latitude.
  const depot = (lat: 22.678, lng: 77.0);
  final start = DateTime.utc(2026, 11, 1, 8);

  DepotDwellTracker tracker() => DepotDwellTracker(depot: depot);

  test('parked inside the radius for 3 h → fires once at the limit', () {
    final dwell = tracker();
    final inside = (lat: 22.6784, lng: 77.0003); // ~57 m from the depot

    expect(dwell.update(inside, start), isFalse);
    expect(
      dwell.update(inside, start.add(const Duration(hours: 2, minutes: 59))),
      isFalse,
    );
    expect(
      dwell.update(inside, start.add(const Duration(hours: 3))),
      isTrue,
    );
    // Single latch: the run already reported the auto-end.
    expect(
      dwell.update(inside, start.add(const Duration(hours: 4))),
      isFalse,
    );
    expect(dwell.fired, isTrue);
  });

  test('leaving the 500 m radius restarts the clock', () {
    final dwell = tracker();
    final inside = (lat: 22.678, lng: 77.0);
    final outside = (lat: 22.684, lng: 77.0); // ~667 m

    expect(dwell.update(inside, start), isFalse);
    expect(
      dwell.update(outside, start.add(const Duration(hours: 2))),
      isFalse,
    );
    expect(dwell.insideSince, isNull);

    final back = start.add(const Duration(hours: 2, minutes: 30));
    expect(dwell.update(inside, back), isFalse);
    expect(
      dwell.update(inside, back.add(const Duration(hours: 2, minutes: 59))),
      isFalse,
    );
    expect(
      dwell.update(inside, back.add(const Duration(hours: 3))),
      isTrue,
    );
  });

  test('moving more than 100 m inside the yard restarts the clock', () {
    final dwell = tracker();
    final first = (lat: 22.678, lng: 77.0);
    final moved = (lat: 22.680, lng: 77.0); // ~222 m, still inside 500 m

    expect(dwell.update(first, start), isFalse);
    expect(
      dwell.update(first, start.add(const Duration(hours: 2))),
      isFalse,
    );

    // The 222 m move at +2 h 10 resets the clock to that moment.
    final rest = start.add(const Duration(hours: 2, minutes: 10));
    expect(dwell.update(moved, rest), isFalse);
    expect(
      dwell.update(moved, rest.add(const Duration(hours: 2, minutes: 59))),
      isFalse,
    );
    expect(
      dwell.update(moved, rest.add(const Duration(hours: 3))),
      isTrue,
    );
  });

  test('shuffling less than 100 m does not restart the clock', () {
    final dwell = tracker();
    final first = (lat: 22.678, lng: 77.0);
    final shifted = (lat: 22.6784, lng: 77.0); // ~44 m

    expect(dwell.update(first, start), isFalse);
    expect(
      dwell.update(shifted, start.add(const Duration(hours: 1))),
      isFalse,
    );
    expect(
      dwell.update(first, start.add(const Duration(hours: 3))),
      isTrue,
    );
  });

  test('outside the radius from the start never fires', () {
    final dwell = tracker();
    final outside = (lat: 22.684, lng: 77.0);

    expect(dwell.update(outside, start), isFalse);
    expect(
      dwell.update(outside, start.add(const Duration(hours: 6))),
      isFalse,
    );
    expect(dwell.insideSince, isNull);
  });
}
