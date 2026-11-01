/// Start Shift core tests (ticket 7, PRD-2 §0.16): `StartShift.execute`
/// now takes the confirmed `Driver` and writes `trip.driverId` +
/// `trip.wardIds` on a fresh start. Pure Dart — fakes only, no Firebase,
/// no platform channels.
library;

import 'package:driverapp/core/config/firebase_bootstrap.dart'
    show MessagingGateway;
import 'package:driverapp/core/domain/ist_clock.dart';
import 'package:driverapp/core/models/models.dart';
import 'package:driverapp/features/shift_start/domain/start_shift.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../models/sample_maps.dart';
import '../../repositories/fake_repositories.dart';

Van sampleVan({String id = 'van-01', String routeId = 'route-van'}) =>
    Van.fromMap(<String, Object?>{
      'id': id,
      'plateNo': 'GJ-05-AB-1234',
      'routeId': routeId,
      'status': 'idle',
      'lastLocation': null,
      'currentTripId': null,
      'batteryPct': 80,
    });

Driver sampleDriver({String id = 'AB-1234', List<String>? wardIds}) =>
    Driver.fromMap(<String, Object?>{
      ...driverDocMap(id: id),
      'wardIds': wardIds ?? const ['ward-01', 'ward-02'],
    });

class RecordingMessagingGateway implements MessagingGateway {
  final List<String> topics = [];
  @override
  Future<void> init() async {}
  @override
  Future<void> subscribeToTopic(String topic) async {
    topics.add(topic);
  }
}

void main() {
  group('StartShift.execute takes the driver (0.16)', () {
    test('fresh start writes trip.driverId + trip.wardIds from the driver '
        'and vanId/routeId from the van', () async {
      final trips = FakeTripsRepository();
      final vans = FakeVansRepository([sampleVan()]);
      final messaging = RecordingMessagingGateway();
      final startShift = StartShift(trips: trips, vans: vans, messaging: messaging);
      final driver = sampleDriver(wardIds: const ['ward-01', 'ward-02']);
      final now = DateTime(2026, 10, 20, 7, 30);

      final session = await startShift.execute(sampleVan(), driver, now);

      expect(session.vanId, 'van-01');
      expect(session.routeId, 'route-van');
      expect(session.tripId, isNotEmpty);

      final trip = trips.trips.values.single;
      expect(trip.vanId, 'van-01');
      expect(trip.routeId, 'route-van');
      expect(trip.driverId, 'AB-1234');
      expect(trip.wardIds, const ['ward-01', 'ward-02']);
      expect(isSameDayIST(trip.date, now), isTrue);

      final van = vans.vans['van-01']!;
      expect(van.status, VanStatus.onShift);
      expect(van.currentTripId, trip.id);

      expect(messaging.topics, ['van_van-01']);
    });

    test('fresh start with a driver allotted a single ward', () async {
      final trips = FakeTripsRepository();
      final vans = FakeVansRepository([sampleVan()]);
      final messaging = RecordingMessagingGateway();
      final startShift = StartShift(trips: trips, vans: vans, messaging: messaging);
      final driver = sampleDriver(wardIds: const ['ward-03']);

      await startShift.execute(sampleVan(), driver, DateTime(2026, 10, 20, 7, 30));

      final trip = trips.trips.values.single;
      expect(trip.driverId, 'AB-1234');
      expect(trip.wardIds, const ['ward-03']);
    });

    test('resume branch reattaches the existing trip (no driver writes, no '
        'duplicate trip)', () async {
      final existingTrip = Trip.fromMap(<String, Object?>{
        ...tripDocMap(id: 'trip-resume'),
        'driverId': 'AB-1234',
        'wardIds': <String>['ward-01', 'ward-02'],
        'startedAt': DateTime(2026, 10, 20, 6, 0),
        'date': DateTime(2026, 10, 20),
      });
      final trips = FakeTripsRepository([existingTrip]);
      final vans = FakeVansRepository([
        Van.fromMap(<String, Object?>{
          ...vanDocMap(),
          'status': 'on_shift',
          'currentTripId': 'trip-resume',
        }),
      ]);
      final messaging = RecordingMessagingGateway();
      final startShift = StartShift(trips: trips, vans: vans, messaging: messaging);
      final driver = sampleDriver();

      final now = DateTime(2026, 10, 20, 8, 0);
      final session = await startShift.execute(
        vans.vans['van-01']!,
        driver,
        now,
      );

      // No second trip created.
      expect(trips.trips, hasLength(1));
      expect(session.tripId, 'trip-resume');
      expect(session.startedAt, existingTrip.startedAt);
      expect(session.date, existingTrip.date);
      expect(vans.vans['van-01']!.currentTripId, 'trip-resume');
      expect(messaging.topics, ['van_van-01']);
    });

    test('resume is BLOCKED when the open trip belongs to another driver '
        '(a van is shared — never take over)', () async {
      final existingTrip = Trip.fromMap(<String, Object?>{
        ...tripDocMap(id: 'trip-resume'),
        'driverId': 'AB-1001',
        'wardIds': <String>['ward-01'],
        'startedAt': DateTime(2026, 10, 20, 6, 0),
        'date': DateTime(2026, 10, 20),
      });
      final trips = FakeTripsRepository([existingTrip]);
      final vans = FakeVansRepository([
        Van.fromMap(<String, Object?>{
          ...vanDocMap(),
          'status': 'on_shift',
          'currentTripId': 'trip-resume',
        }),
      ]);
      final startShift = StartShift(
        trips: trips,
        vans: vans,
        messaging: RecordingMessagingGateway(),
      );

      // AB-1002 sits on the same van — the shift is not theirs.
      await expectLater(
        startShift.execute(
          vans.vans['van-01']!,
          sampleDriver(id: 'AB-1002'),
          DateTime(2026, 10, 20, 8, 0),
        ),
        throwsA(isA<ShiftStartConflict>()),
      );

      // The other driver's trip doc is untouched — no take-over, no write.
      expect(trips.trips['trip-resume']!.driverId, 'AB-1001');
      expect(trips.trips, hasLength(1));
    });

    test('resume is ALLOWED when the open trip carries no driverId (a '
        'pre-0.16 trip keeps working)', () async {
      final existingTrip = Trip.fromMap(<String, Object?>{
        ...tripDocMap(id: 'trip-resume'),
        'startedAt': DateTime(2026, 10, 20, 6, 0),
        'date': DateTime(2026, 10, 20),
      });
      final trips = FakeTripsRepository([existingTrip]);
      final vans = FakeVansRepository([
        Van.fromMap(<String, Object?>{
          ...vanDocMap(),
          'status': 'on_shift',
          'currentTripId': 'trip-resume',
        }),
      ]);
      final startShift = StartShift(
        trips: trips,
        vans: vans,
        messaging: RecordingMessagingGateway(),
      );

      final session = await startShift.execute(
        vans.vans['van-01']!,
        sampleDriver(id: 'AB-1002'),
        DateTime(2026, 10, 20, 8, 0),
      );

      expect(session.tripId, 'trip-resume');
      expect(trips.trips, hasLength(1));
    });

    test('resume is BLOCKED when the marker points at another van\u2019s trip '
        '(a stale marker is a conflict, never invented state)', () async {
      final otherVanTrip = Trip.fromMap(<String, Object?>{
        ...tripDocMap(id: 'trip-other-van'),
        'vanId': 'van-09',
        'driverId': 'AB-1001',
        'wardIds': <String>['ward-01'],
        'startedAt': DateTime(2026, 10, 20, 6, 0),
        'date': DateTime(2026, 10, 20),
      });
      final trips = FakeTripsRepository([otherVanTrip]);
      final vans = FakeVansRepository([
        Van.fromMap(<String, Object?>{
          ...vanDocMap(),
          'status': 'on_shift',
          'currentTripId': 'trip-other-van',
        }),
      ]);
      final startShift = StartShift(
        trips: trips,
        vans: vans,
        messaging: RecordingMessagingGateway(),
      );

      await expectLater(
        startShift.execute(
          vans.vans['van-01']!,
          sampleDriver(id: 'AB-1001'), // even the trip's own driver
          DateTime(2026, 10, 20, 8, 0),
        ),
        throwsA(isA<ShiftStartConflict>()),
      );

      // Nothing was written to the mismatched trip.
      expect(trips.trips['trip-other-van']!.vanId, 'van-09');
      expect(trips.trips, hasLength(1));
    });
  });
}
