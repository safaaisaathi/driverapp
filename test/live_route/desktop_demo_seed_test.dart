/// Desktop dev-seed trip tests (ticket 7, PRD-2 §0.16): the in-memory
/// trip double must keep the 0.16 identity fields (`driverId`, `wardIds`)
/// across its own mutations — the dev preview shows the same contract
/// shape the device does.
library;

import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/live_route/dev/desktop_demo_seed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A started trip carrying the 0.16 identity: the confirmed driver code
  /// and the driver's allotted wards.
  Trip startedTrip() => Trip.fromMap(<String, Object?>{
        'id': 'dev-trip-1',
        'vanId': 'van-01',
        'routeId': 'route-01',
        'driverId': 'AB-1234',
        'wardIds': <String>['ward-1', 'ward-2'],
        'date': DateTime(2026, 10, 30),
        'startedAt': DateTime(2026, 10, 30, 7, 30),
        'endedAt': null,
        'wardsDone': const <Object?>[],
        'alertedWardIds': const <Object?>[],
        'gpsTrail': const <Object?>[],
        'mockLocationDetected': false,
      });

  test('a ward-done append keeps the trip driverId + wardIds', () async {
    final trips = DevTripsRepository()..seedTrip(startedTrip());

    await trips.appendWardDone(
      'dev-trip-1',
      WardDone(
        wardId: 'ward-1',
        doneAt: DateTime(2026, 10, 30, 8),
        flagged: false,
      ),
    );

    final trip = await trips.readTrip('dev-trip-1');
    expect(trip, isNotNull);
    expect(trip!.driverId, 'AB-1234');
    expect(trip.wardIds, const ['ward-1', 'ward-2']);
    expect(trip.wardsDone, hasLength(1));
  });

  test('a trail append keeps the trip driverId + wardIds', () async {
    final trips = DevTripsRepository()..seedTrip(startedTrip());

    await trips.appendGpsTrail(
      'dev-trip-1',
      [GpsPoint(lat: 23.03, lng: 72.58, t: DateTime(2026, 10, 30, 8))],
    );

    final trip = await trips.readTrip('dev-trip-1');
    expect(trip!.driverId, 'AB-1234');
    expect(trip.wardIds, const ['ward-1', 'ward-2']);
    expect(trip.gpsTrail, hasLength(1));
  });

  test('ending the shift keeps the trip driverId + wardIds', () async {
    final trips = DevTripsRepository()..seedTrip(startedTrip());

    await trips.setEndedAt('dev-trip-1', DateTime(2026, 10, 30, 13, 25));

    final trip = await trips.readTrip('dev-trip-1');
    expect(trip!.driverId, 'AB-1234');
    expect(trip.wardIds, const ['ward-1', 'ward-2']);
    expect(trip.endedAt, isNotNull);
  });

  group('the seeded demo van', () {
    test('the live-route demo seeds it on shift with an open trip', () async {
      final seed = DevDesktopSeed();

      final van = await seed.vans.readVan(devSeedVanId);
      expect(van!.status, VanStatus.onShift);
      expect(van.currentTripId, devSeedTripId);
    });

    test('parkAsIdle puts it on idle with no open trip (the identity '
        'previews need the FRESH start path)', () async {
      final seed = DevDesktopSeed();

      seed.vans.parkAsIdle(devSeedVanId);

      final van = await seed.vans.readVan(devSeedVanId);
      expect(van!.status, VanStatus.idle);
      expect(van.currentTripId, isNull);
      // The rest of the van survives (the map still has a position).
      expect(van.lastLocation, isNotNull);
      expect(van.plateNo, isNotEmpty);
    });
  });
}
